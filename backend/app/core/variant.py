import random
from typing import Optional

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import Survey


# Префикс Redis-ключа для round-robin счётчика. Один счётчик на родительский
# опрос; INCR атомарный, так что параллельные `/start` гарантированно получат
# разные номера. Сброс — через DEL того же ключа.
_RR_KEY = "survey:{sid}:rr_counter"


def rr_counter_key(survey_id: int) -> str:
    return _RR_KEY.format(sid=survey_id)


async def pick_variant(
    db: AsyncSession,
    survey: Survey,
    *,
    redis=None,
    increment: bool = True,
) -> Survey:
    """Pick a variant of `survey` for the next respondent.

    Two modes:

      * ``random`` — взвешенный случайный выбор по ``variant_weight``. Базовое
        поведение; для большой выборки распределение сходится к заданному.

      * ``round_robin`` — детерминированный круг. Респонденты по очереди
        получают варианты в порядке [original, variant_A, variant_B, ...].
        Счётчик хранится в Redis и инкрементится атомарно — конкурентные
        ``/start`` не могут получить один и тот же номер. На малой выборке
        даёт точное равное распределение.

    ``increment=False`` нужен для превью-эндпоинта ``GET /public/surveys/{slug}``:
    он выбирает один из вариантов «для отображения», но не должен прожигать
    счётчик — иначе один пользователь, открывший страницу и нажавший
    «Начать», утянет два номера.
    """
    res = await db.execute(select(Survey).where(Survey.parent_survey_id == survey.id))
    variants = list(res.scalars())
    if not variants:
        return survey
    pool = [survey, *variants]

    mode = (survey.assignment_mode or "random").lower()

    if mode == "round_robin" and redis is not None:
        if increment:
            idx = await redis.incr(rr_counter_key(survey.id))
        else:
            # Превью: подглядываем текущий счётчик, не меняя его. Если ещё
            # никто не стартовал — покажем "следующего" (первого).
            current = await redis.get(rr_counter_key(survey.id))
            idx = (int(current) if current else 0) + 1
        return pool[(idx - 1) % len(pool)]

    # Дефолт — взвешенный random.
    weights = [max(0.0, s.variant_weight or 0.0) for s in pool]
    total = sum(weights)
    if total <= 0:
        return random.choice(pool)
    return random.choices(pool, weights=weights, k=1)[0]

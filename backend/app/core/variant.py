import random
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..models import Survey


async def pick_variant(db: AsyncSession, survey: Survey) -> Survey:
    """Return a child variant chosen by weight, or the survey itself if no variants."""
    res = await db.execute(select(Survey).where(Survey.parent_survey_id == survey.id))
    variants = list(res.scalars())
    if not variants:
        return survey
    pool = [survey, *variants]
    weights = [max(0.0, s.variant_weight or 0.0) for s in pool]
    total = sum(weights)
    if total <= 0:
        return random.choice(pool)
    return random.choices(pool, weights=weights, k=1)[0]

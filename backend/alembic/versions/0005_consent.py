"""add consent_required and consent_text to surveys

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-14

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # consent_required: bool, NOT NULL, default FALSE. Все существующие
    # опросы сохранят прежнее поведение (без модалки согласия). На
    # Postgres 11+ добавление NOT NULL колонки с server_default —
    # мгновенная операция без блокировки таблицы.
    op.add_column(
        "surveys",
        sa.Column(
            "consent_required",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    # consent_text: длинный текст согласия. NULL разрешён — если
    # пользователь включил тумблер, но ничего не написал, UI подставит
    # дефолтный шаблон. Хранить шаблон в БД не нужно — он живёт в коде
    # фронтенда и помогает легко обновлять без миграции.
    op.add_column(
        "surveys",
        sa.Column("consent_text", sa.Text(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("surveys", "consent_text")
    op.drop_column("surveys", "consent_required")

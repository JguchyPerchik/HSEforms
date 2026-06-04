"""add assignment_mode to surveys

Revision ID: 0004
Revises: 0003
Create Date: 2026-06-04 00:00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 'random' — текущее поведение, взвешенный случайный выбор по variant_weight.
    # 'round_robin' — детерминированный круг: 1-й респондент получает 1-й
    # вариант, 2-й — 2-й, и так далее. Считается через Redis INCR.
    op.add_column(
        "surveys",
        sa.Column(
            "assignment_mode",
            sa.String(20),
            nullable=False,
            server_default=sa.text("'random'"),
        ),
    )


def downgrade() -> None:
    op.drop_column("surveys", "assignment_mode")

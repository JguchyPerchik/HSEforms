"""add is_synthetic + synthetic_profile to responses

Revision ID: 0003
Revises: 0002
Create Date: 2026-05-20 00:00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "0003"
down_revision: Union[str, None] = "0002"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "responses",
        sa.Column(
            "is_synthetic",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
    )
    op.add_column(
        "responses",
        sa.Column(
            "synthetic_profile",
            postgresql.JSONB(),
            nullable=False,
            server_default=sa.text("'{}'::jsonb"),
        ),
    )
    op.create_index("ix_responses_is_synthetic", "responses", ["is_synthetic"])


def downgrade() -> None:
    op.drop_index("ix_responses_is_synthetic", table_name="responses")
    op.drop_column("responses", "synthetic_profile")
    op.drop_column("responses", "is_synthetic")

"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-05-14 00:00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    survey_status = postgresql.ENUM(
        "draft", "published", "closed", name="survey_status", create_type=False
    )
    question_type = postgresql.ENUM(
        "short_text", "long_text", "single_choice", "multiple_choice",
        "dropdown", "scale", "rating", "number", "date", "time",
        "email", "file_upload", "section_header",
        name="question_type", create_type=False,
    )
    collab_role = postgresql.ENUM(
        "owner", "editor", "viewer", name="collab_role", create_type=False
    )
    op.execute("CREATE TYPE survey_status AS ENUM ('draft','published','closed')")
    op.execute(
        "CREATE TYPE question_type AS ENUM "
        "('short_text','long_text','single_choice','multiple_choice',"
        "'dropdown','scale','rating','number','date','time','email',"
        "'file_upload','section_header')"
    )
    op.execute("CREATE TYPE collab_role AS ENUM ('owner','editor','viewer')")

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("password_hash", sa.String(255), nullable=True),
        sa.Column("full_name", sa.String(255), nullable=True),
        sa.Column("telegram_id", sa.BigInteger(), nullable=True),
        sa.Column("telegram_username", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_users_email", "users", ["email"], unique=True)
    op.create_index("ix_users_telegram_id", "users", ["telegram_id"], unique=True)

    op.create_table(
        "surveys",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("title", sa.String(500), nullable=False, server_default="Без названия"),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("slug", sa.String(32), nullable=False),
        sa.Column("status", survey_status, nullable=False, server_default="draft"),
        sa.Column("is_anonymous", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("one_response_per_user", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("allow_back_navigation", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("show_progress", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("theme", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("parent_survey_id", sa.Integer(), sa.ForeignKey("surveys.id", ondelete="CASCADE"), nullable=True),
        sa.Column("variant_weight", sa.Float(), nullable=False, server_default="1.0"),
        sa.Column("variant_label", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("published_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_surveys_owner_id", "surveys", ["owner_id"])
    op.create_index("ix_surveys_slug", "surveys", ["slug"], unique=True)
    op.create_index("ix_surveys_status", "surveys", ["status"])
    op.create_index("ix_surveys_parent_survey_id", "surveys", ["parent_survey_id"])

    op.create_table(
        "questions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("survey_id", sa.Integer(), sa.ForeignKey("surveys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("type", question_type, nullable=False),
        sa.Column("title", sa.Text(), nullable=False, server_default=""),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("page_break_before", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("required", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("config", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("display_condition", postgresql.JSONB(), nullable=True),
        sa.Column("media_url", sa.String(2000), nullable=True),
    )
    op.create_index("ix_questions_survey_id", "questions", ["survey_id"])
    op.create_index("ix_questions_position", "questions", ["position"])

    op.create_table(
        "question_options",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("question_id", sa.Integer(), sa.ForeignKey("questions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("label", sa.Text(), nullable=False, server_default=""),
        sa.Column("value", sa.String(255), nullable=False, server_default=""),
        sa.Column("position", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("media_url", sa.String(2000), nullable=True),
    )
    op.create_index("ix_question_options_question_id", "question_options", ["question_id"])

    op.create_table(
        "responses",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("survey_id", sa.Integer(), sa.ForeignKey("surveys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("anon_token", sa.String(64), nullable=True),
        sa.Column("is_complete", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("started_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_responses_survey_id", "responses", ["survey_id"])
    op.create_index("ix_responses_user_id", "responses", ["user_id"])
    op.create_index("ix_responses_anon_token", "responses", ["anon_token"])

    op.create_table(
        "answers",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("response_id", sa.Integer(), sa.ForeignKey("responses.id", ondelete="CASCADE"), nullable=False),
        sa.Column("question_id", sa.Integer(), sa.ForeignKey("questions.id", ondelete="CASCADE"), nullable=False),
        sa.Column("value", postgresql.JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
    )
    op.create_index("ix_answers_response_id", "answers", ["response_id"])
    op.create_index("ix_answers_question_id", "answers", ["question_id"])

    op.create_table(
        "survey_collaborators",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("survey_id", sa.Integer(), sa.ForeignKey("surveys.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("role", collab_role, nullable=False, server_default="editor"),
        sa.UniqueConstraint("survey_id", "user_id", name="uq_survey_user"),
    )
    op.create_index("ix_survey_collaborators_survey_id", "survey_collaborators", ["survey_id"])
    op.create_index("ix_survey_collaborators_user_id", "survey_collaborators", ["user_id"])


def downgrade() -> None:
    op.drop_table("survey_collaborators")
    op.drop_table("answers")
    op.drop_table("responses")
    op.drop_table("question_options")
    op.drop_table("questions")
    op.drop_table("surveys")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS collab_role")
    op.execute("DROP TYPE IF EXISTS question_type")
    op.execute("DROP TYPE IF EXISTS survey_status")

"""Add SLAM status columns to maps table

Revision ID: 002
Revises: 001
Create Date: 2026-03-24
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "002"
down_revision: Union[str, None] = "001"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("maps", sa.Column("slam_completed", sa.Boolean, default=False, server_default="false"))
    op.add_column("maps", sa.Column("slam_keyframes", sa.Integer, nullable=True))
    op.add_column("maps", sa.Column("slam_frames", sa.Integer, nullable=True))


def downgrade() -> None:
    op.drop_column("maps", "slam_frames")
    op.drop_column("maps", "slam_keyframes")
    op.drop_column("maps", "slam_completed")

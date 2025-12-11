"""
Philia 用户模型
支持设备ID登录和Apple ID登录
"""

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, Index, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class User(Base):
    """
    用户模型
    - 支持设备ID匿名登录（游客模式）
    - 支持Apple ID登录
    - 游客账号可绑定Apple ID升级
    """

    __tablename__ = "users"

    # 主键
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # 设备唯一标识符 (iOS identifierForVendor)
    device_id: Mapped[str] = mapped_column(
        String(128),
        unique=True,
        nullable=False,
        index=True,
    )

    # Apple ID 用户标识符 (Sign in with Apple 的 user identifier)
    apple_id: Mapped[Optional[str]] = mapped_column(
        String(128),
        unique=True,
        nullable=True,
        index=True,
    )

    # Apple ID 关联的邮箱 (可能是隐藏邮箱)
    email: Mapped[Optional[str]] = mapped_column(
        String(255),
        nullable=True,
    )

    # 用户昵称 (可从 Apple ID 获取或自定义)
    nickname: Mapped[Optional[str]] = mapped_column(
        String(100),
        nullable=True,
    )

    # 用户头像 URL
    avatar_url: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # 账号状态: active, suspended, deleted
    status: Mapped[str] = mapped_column(
        String(20),
        default="active",
        nullable=False,
    )

    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # 最后登录时间
    last_login_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True,
    )

    # 关联: 一对多关系 -> targets
    targets: Mapped[list["TargetProfile"]] = relationship(
        "TargetProfile",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # 索引
    __table_args__ = (
        Index("idx_user_status", "status"),
        Index("idx_user_created_at", "created_at"),
    )

    def __repr__(self) -> str:
        return f"<User(id={self.id}, device_id={self.device_id[:8]}...)>"


# 导入 TargetProfile 以避免循环导入问题
from app.models.relationship import TargetProfile  # noqa: E402, F401

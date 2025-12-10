"""
Philia 数据库模型定义
使用 SQLAlchemy ORM
"""

import uuid
from datetime import datetime
from typing import Optional

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class TargetProfile(Base):
    """
    对象档案模型
    存储跟踪的人物档案信息
    """

    __tablename__ = "target_profile"

    # 主键
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # 基础信息
    name: Mapped[str] = mapped_column(Text, nullable=False)
    avatar_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 当前关系状态
    # pursuing (追求中), dating (约会中), friend (朋友), complicated (复杂), ended (已结束)
    current_status: Mapped[str] = mapped_column(
        String(50),
        default="pursuing",
        nullable=True,
    )

    # 动态画像 (JSONB)
    # 结构示例: { "tags": ["E人", "爱旅游"], "mbti": "ENFP", "zodiac": "天蝎座", "age_range": "25-28" }
    profile_data: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        nullable=False,
    )

    # 喜好 (JSONB)
    # 结构示例: { "likes": ["猫", "咖啡"], "dislikes": ["抽烟"] }
    preferences: Mapped[dict] = mapped_column(
        JSONB,
        default=lambda: {"likes": [], "dislikes": []},
        nullable=False,
    )

    # AI 生成的综合摘要
    ai_summary: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

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

    # 关联: 一对多关系 -> memories
    memories: Mapped[list["TargetMemory"]] = relationship(
        "TargetMemory",
        back_populates="target",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # 约束
    __table_args__ = (
        Index("idx_profile_status", "current_status"),
        Index("idx_profile_updated_at", "updated_at"),
    )

    def __repr__(self) -> str:
        return f"<TargetProfile(id={self.id}, name={self.name})>"


class TargetMemory(Base):
    """
    对象记忆模型
    存储每次交互的事件记录
    """

    __tablename__ = "target_memory"

    # 主键
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # 外键: 关联到 TargetProfile
    target_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("target_profile.id", ondelete="CASCADE"),
        nullable=False,
    )

    # 事件发生时间
    happened_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
    )

    # 来源类型
    # wechat, qq, tantan, soul, xiaohongshu, photo, manual
    source_type: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    # 原始内容文本
    content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 原始图片存储路径
    image_url: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 结构化事实 (AI 提取)
    # 示例: { "sentiment": "阴阳怪气", "key_event": "争吵", "topics": ["工作", "约会"] }
    extracted_facts: Mapped[dict] = mapped_column(
        JSONB,
        default=dict,
        nullable=False,
    )

    # 情绪评分 (-10 到 10)
    sentiment_score: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # 向量 Embedding (2048 维 - 豆包 Embedding Large 实际返回维度)
    embedding: Mapped[Optional[list]] = mapped_column(
        Vector(2048),
        nullable=True,
    )

    # 去重指纹
    content_hash: Mapped[Optional[str]] = mapped_column(
        String(64),
        nullable=True,
    )

    # 记忆状态
    # active: 当前有效, outdated: 已过时 (被新记忆替代)
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

    # 关联: 多对一关系 -> target
    target: Mapped["TargetProfile"] = relationship(
        "TargetProfile",
        back_populates="memories",
    )

    # 约束和索引
    __table_args__ = (
        CheckConstraint("sentiment_score >= -10 AND sentiment_score <= 10", name="check_sentiment_score_range"),
        Index("idx_memory_target_id", "target_id"),
        Index("idx_memory_happened_at", "happened_at"),
        Index("idx_memory_source_type", "source_type"),
        Index("idx_memory_content_hash", "content_hash"),
        Index("idx_memory_status", "status"),
    )

    def __repr__(self) -> str:
        return f"<TargetMemory(id={self.id}, source={self.source_type})>"


class Tag(Base):
    """
    标签字典模型
    用于标签标准化和统计
    """

    __tablename__ = "tags"

    # 主键
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # 标签名称
    name: Mapped[str] = mapped_column(
        Text,
        unique=True,
        nullable=False,
    )

    # 标签分类
    # personality (性格), hobby (爱好), appearance (外貌), lifestyle (生活方式)
    category: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
    )

    # 使用次数
    usage_count: Mapped[int] = mapped_column(
        Integer,
        default=0,
        nullable=False,
    )

    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    def __repr__(self) -> str:
        return f"<Tag(name={self.name}, category={self.category})>"

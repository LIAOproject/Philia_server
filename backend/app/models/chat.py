"""
Philia Chat 模块数据库模型
AI 情感导师 Chatbot 相关表
"""

import uuid
from datetime import datetime
from typing import Optional

from sqlalchemy import DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base


class AIMentor(Base):
    """
    AI 导师/咨询师人设模型
    存储预设的咨询师角色配置
    """

    __tablename__ = "ai_mentor"

    # 主键
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # 导师名称
    name: Mapped[str] = mapped_column(
        String(100),
        nullable=False,
    )

    # 导师描述 (展示给用户)
    description: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # System Prompt 模板
    # 支持占位符: {target_name}, {profile_summary}, {preferences}, {context}
    system_prompt_template: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # 图标 URL
    icon_url: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # 导师类型/风格标签
    # 例如: "温柔姐姐", "毒舌闺蜜", "理性分析师"
    style_tag: Mapped[Optional[str]] = mapped_column(
        String(50),
        nullable=True,
    )

    # 是否激活
    is_active: Mapped[bool] = mapped_column(
        default=True,
        nullable=False,
    )

    # 排序权重 (越小越靠前)
    sort_order: Mapped[int] = mapped_column(
        default=0,
        nullable=False,
    )

    # ====== RAG 默认设置 ======

    # 默认 RAG 设置 (JSONB)
    # 结构: { "enabled": true, "max_memories": 5, "time_decay_factor": 0.1, "min_relevance_score": 0.0 }
    default_rag_settings: Mapped[dict] = mapped_column(
        JSONB,
        default=lambda: {
            "enabled": True,
            "max_memories": 5,
            "max_recent_messages": 10,
            "time_decay_factor": 0.1,
            "min_relevance_score": 0.0,
        },
        nullable=False,
    )

    # 默认 RAG 语料库 (JSONB) - 导师专属的知识库
    # 结构: [{ "content": "...", "metadata": {...} }, ...]
    default_rag_corpus: Mapped[list] = mapped_column(
        JSONB,
        default=list,
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

    # 关联: 一对多 -> Chatbot
    chatbots: Mapped[list["Chatbot"]] = relationship(
        "Chatbot",
        back_populates="mentor",
        lazy="selectin",
    )

    __table_args__ = (
        Index("idx_mentor_is_active", "is_active"),
        Index("idx_mentor_sort_order", "sort_order"),
    )

    def __repr__(self) -> str:
        return f"<AIMentor(id={self.id}, name={self.name})>"


class Chatbot(Base):
    """
    聊天机器人实例模型
    用户创建的会话实例，关联特定 Target 和 Mentor
    """

    __tablename__ = "chatbot"

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

    # 外键: 关联到 AIMentor
    mentor_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("ai_mentor.id", ondelete="CASCADE"),
        nullable=False,
    )

    # 会话标题 (可自定义或自动生成)
    title: Mapped[str] = mapped_column(
        String(200),
        nullable=False,
    )

    # 会话状态: active, archived
    status: Mapped[str] = mapped_column(
        String(20),
        default="active",
        nullable=False,
    )

    # ====== 调试/自定义设置 ======

    # 自定义系统提示词 (覆盖 mentor 的模板)
    custom_system_prompt: Mapped[Optional[str]] = mapped_column(
        Text,
        nullable=True,
    )

    # RAG 设置 (JSONB)
    # 结构: { "enabled": true, "max_memories": 5, "time_decay_factor": 0.1, "min_relevance_score": 0.0 }
    rag_settings: Mapped[dict] = mapped_column(
        JSONB,
        default=lambda: {
            "enabled": True,
            "max_memories": 5,
            "max_recent_messages": 10,
            "time_decay_factor": 0.1,
            "min_relevance_score": 0.0,
        },
        nullable=False,
    )

    # RAG 语料库 (JSONB) - 额外的自定义语料
    # 结构: [{ "content": "...", "metadata": {...} }, ...]
    rag_corpus: Mapped[list] = mapped_column(
        JSONB,
        default=list,
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

    # 关联
    target: Mapped["TargetProfile"] = relationship(
        "TargetProfile",
        backref="chatbots",
    )
    mentor: Mapped["AIMentor"] = relationship(
        "AIMentor",
        back_populates="chatbots",
    )
    messages: Mapped[list["ChatMessage"]] = relationship(
        "ChatMessage",
        back_populates="chatbot",
        cascade="all, delete-orphan",
        lazy="selectin",
        order_by="ChatMessage.created_at",
    )

    __table_args__ = (
        Index("idx_chatbot_target_id", "target_id"),
        Index("idx_chatbot_mentor_id", "mentor_id"),
        Index("idx_chatbot_status", "status"),
        Index("idx_chatbot_updated_at", "updated_at"),
    )

    def __repr__(self) -> str:
        return f"<Chatbot(id={self.id}, title={self.title})>"


class ChatMessage(Base):
    """
    聊天消息模型
    存储每条对话消息
    """

    __tablename__ = "chat_message"

    # 主键
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )

    # 外键: 关联到 Chatbot
    chatbot_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("chatbot.id", ondelete="CASCADE"),
        nullable=False,
    )

    # 角色: user / assistant
    role: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
    )

    # 消息内容
    content: Mapped[str] = mapped_column(
        Text,
        nullable=False,
    )

    # 消息元数据 (可选，存储额外信息如 token 数、模型信息等)
    # 注意: 使用 message_metadata 避免与 SQLAlchemy 保留字冲突
    message_metadata: Mapped[Optional[dict]] = mapped_column(
        "metadata",  # 数据库列名仍为 metadata
        JSONB,
        default=None,
        nullable=True,
    )

    # 时间戳
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    # 关联
    chatbot: Mapped["Chatbot"] = relationship(
        "Chatbot",
        back_populates="messages",
    )

    __table_args__ = (
        Index("idx_message_chatbot_id", "chatbot_id"),
        Index("idx_message_created_at", "created_at"),
    )

    def __repr__(self) -> str:
        return f"<ChatMessage(id={self.id}, role={self.role})>"


# 导入 TargetProfile 以支持关联 (避免循环导入)
from app.models.relationship import TargetProfile  # noqa: E402, F401

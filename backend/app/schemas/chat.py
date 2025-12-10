"""
Philia Chat 模块 Pydantic Schema 定义
用于 API 请求/响应数据验证
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ========================
# AIMentor (AI 导师) Schemas
# ========================


class RAGSettings(BaseModel):
    """RAG 设置"""

    enabled: bool = Field(True, description="是否启用 RAG")
    max_memories: int = Field(5, ge=0, le=20, description="最大检索记忆数")
    max_recent_messages: int = Field(10, ge=0, le=50, description="最大历史消息数")
    time_decay_factor: float = Field(0.1, ge=0, le=1, description="时间衰减因子")
    min_relevance_score: float = Field(0.0, ge=0, le=1, description="最小相关性分数")


class RAGCorpusItem(BaseModel):
    """RAG 语料条目"""

    content: str = Field(..., description="语料内容")
    metadata: Optional[dict] = Field(default_factory=dict, description="元数据")


class AIMentorCreate(BaseModel):
    """创建 AI 导师请求"""

    name: str = Field(..., min_length=1, max_length=100, description="导师名称")
    description: str = Field(..., min_length=1, description="导师描述")
    system_prompt_template: str = Field(..., description="System Prompt 模板")
    icon_url: Optional[str] = Field(None, description="图标 URL")
    style_tag: Optional[str] = Field(None, max_length=50, description="风格标签")
    sort_order: int = Field(0, description="排序权重")
    # RAG 设置
    default_rag_settings: Optional[RAGSettings] = Field(None, description="默认 RAG 设置")
    default_rag_corpus: Optional[list[RAGCorpusItem]] = Field(None, description="默认 RAG 语料库")


class AIMentorUpdate(BaseModel):
    """更新 AI 导师请求"""

    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, min_length=1)
    system_prompt_template: Optional[str] = None
    icon_url: Optional[str] = None
    style_tag: Optional[str] = Field(None, max_length=50)
    is_active: Optional[bool] = None
    sort_order: Optional[int] = None
    # RAG 设置
    default_rag_settings: Optional[RAGSettings] = None
    default_rag_corpus: Optional[list[RAGCorpusItem]] = None


class AIMentorResponse(BaseModel):
    """AI 导师响应"""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    description: str
    system_prompt_template: str
    icon_url: Optional[str]
    style_tag: Optional[str]
    is_active: bool
    sort_order: int
    # RAG 设置
    default_rag_settings: dict = Field(default_factory=dict)
    default_rag_corpus: list = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class AIMentorListResponse(BaseModel):
    """AI 导师列表响应"""

    total: int
    items: list[AIMentorResponse]


# ========================
# Chatbot (聊天机器人) Schemas
# ========================


class ChatbotCreate(BaseModel):
    """创建 Chatbot 请求"""

    target_id: UUID = Field(..., description="关联的对象 ID")
    mentor_id: UUID = Field(..., description="使用的导师 ID")
    title: Optional[str] = Field(None, max_length=200, description="会话标题")


class ChatbotUpdate(BaseModel):
    """更新 Chatbot 请求"""

    title: Optional[str] = Field(None, max_length=200)
    status: Optional[str] = Field(None, pattern="^(active|archived)$")


class ChatbotResponse(BaseModel):
    """Chatbot 响应"""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    target_id: UUID
    mentor_id: UUID
    title: str
    status: str
    created_at: datetime
    updated_at: datetime
    # 嵌套信息
    target_name: Optional[str] = None
    mentor_name: Optional[str] = None
    mentor_icon_url: Optional[str] = None
    message_count: Optional[int] = None


class ChatbotListResponse(BaseModel):
    """Chatbot 列表响应"""

    total: int
    items: list[ChatbotResponse]


class ChatbotDetailResponse(ChatbotResponse):
    """Chatbot 详情响应 (包含最近消息)"""

    recent_messages: list["ChatMessageResponse"] = Field(default_factory=list)


class ChatbotDebugSettings(BaseModel):
    """Chatbot 调试设置响应"""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    # 导师原始系统提示词模板
    mentor_system_prompt_template: str = Field(..., description="导师原始系统提示词模板")
    # 自定义系统提示词 (覆盖导师模板)
    custom_system_prompt: Optional[str] = Field(None, description="自定义系统提示词")
    # 当前生效的系统提示词 (渲染后的完整版本)
    effective_system_prompt: Optional[str] = Field(None, description="当前生效的系统提示词")
    # RAG 设置
    rag_settings: RAGSettings = Field(default_factory=RAGSettings)
    # RAG 语料库
    rag_corpus: list[RAGCorpusItem] = Field(default_factory=list)


class ChatbotDebugSettingsUpdate(BaseModel):
    """更新 Chatbot 调试设置请求"""

    custom_system_prompt: Optional[str] = Field(None, description="自定义系统提示词 (设为空字符串清除)")
    rag_settings: Optional[RAGSettings] = Field(None, description="RAG 设置")
    rag_corpus: Optional[list[RAGCorpusItem]] = Field(None, description="RAG 语料库")


# ========================
# ChatMessage (聊天消息) Schemas
# ========================


class ChatMessageCreate(BaseModel):
    """创建聊天消息请求 (内部使用)"""

    chatbot_id: UUID
    role: str = Field(..., pattern="^(user|assistant)$")
    content: str


class ChatMessageResponse(BaseModel):
    """聊天消息响应"""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    chatbot_id: UUID
    role: str
    content: str
    created_at: datetime


class ChatMessageListResponse(BaseModel):
    """聊天消息列表响应"""

    total: int
    items: list[ChatMessageResponse]


# ========================
# Chat API Schemas
# ========================


class SendMessageRequest(BaseModel):
    """发送消息请求"""

    message: str = Field(..., min_length=1, max_length=5000, description="用户消息")


class SendMessageResponse(BaseModel):
    """发送消息响应"""

    user_message: ChatMessageResponse
    assistant_message: ChatMessageResponse
    memories_retrieved: int = Field(0, description="RAG 检索到的记忆数量")
    memory_created: bool = Field(False, description="是否从对话中创建了新记忆")


class StreamChunk(BaseModel):
    """流式响应块"""

    type: str = Field(..., description="chunk 类型: text, done, error")
    content: Optional[str] = None
    message_id: Optional[UUID] = None


# ========================
# Context & RAG Schemas
# ========================


class RetrievedMemory(BaseModel):
    """RAG 检索到的记忆"""

    id: UUID
    content: str
    happened_at: datetime
    source_type: str
    sentiment_score: int
    relevance_score: Optional[float] = None


class ChatContext(BaseModel):
    """聊天上下文 (内部使用)"""

    target_name: str
    profile_summary: str
    preferences: str
    retrieved_memories: list[RetrievedMemory]
    recent_messages: list[ChatMessageResponse]


# 更新 forward reference
ChatbotDetailResponse.model_rebuild()

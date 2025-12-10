"""
Relation-OS Pydantic Schema 定义
用于 API 请求/响应数据验证
"""

from datetime import datetime
from typing import Any, Optional
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


# ========================
# Target (关系对象) Schemas
# ========================


class ProfileData(BaseModel):
    """画像数据结构"""

    tags: list[str] = Field(default_factory=list, description="特征标签列表")
    mbti: Optional[str] = Field(None, description="MBTI 类型")
    zodiac: Optional[str] = Field(None, description="星座")
    age_range: Optional[str] = Field(None, description="年龄范围")
    occupation: Optional[str] = Field(None, description="职业")
    location: Optional[str] = Field(None, description="所在地")
    education: Optional[str] = Field(None, description="学历")
    appearance: Optional[dict[str, Any]] = Field(None, description="外貌特征")
    personality: Optional[dict[str, Any]] = Field(None, description="性格特征")


class Preferences(BaseModel):
    """喜好数据结构"""

    likes: list[str] = Field(default_factory=list, description="喜欢的事物")
    dislikes: list[str] = Field(default_factory=list, description="不喜欢的事物")


class TargetCreate(BaseModel):
    """创建关系对象请求"""

    name: str = Field(..., min_length=1, max_length=100, description="对象名称")
    avatar_url: Optional[str] = Field(None, description="头像 URL")
    current_status: str = Field("pursuing", description="当前关系状态")
    profile_data: Optional[dict[str, Any]] = Field(default_factory=dict, description="画像数据")
    preferences: Optional[dict[str, Any]] = Field(
        default_factory=lambda: {"likes": [], "dislikes": []},
        description="喜好数据",
    )


class TargetUpdate(BaseModel):
    """更新关系对象请求"""

    name: Optional[str] = Field(None, min_length=1, max_length=100, description="对象名称")
    avatar_url: Optional[str] = Field(None, description="头像 URL")
    current_status: Optional[str] = Field(None, description="当前关系状态")
    profile_data: Optional[dict[str, Any]] = Field(None, description="画像数据")
    preferences: Optional[dict[str, Any]] = Field(None, description="喜好数据")
    ai_summary: Optional[str] = Field(None, description="AI 摘要")


class TargetResponse(BaseModel):
    """关系对象响应"""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    avatar_url: Optional[str]
    current_status: Optional[str]
    profile_data: dict[str, Any]
    preferences: dict[str, Any]
    ai_summary: Optional[str]
    created_at: datetime
    updated_at: datetime
    memory_count: Optional[int] = Field(None, description="记忆数量")


class TargetListResponse(BaseModel):
    """关系对象列表响应"""

    total: int
    items: list[TargetResponse]


# ========================
# Memory (记忆) Schemas
# ========================


class ExtractedFacts(BaseModel):
    """提取的事实结构"""

    sentiment: Optional[str] = Field(None, description="情绪类型")
    key_event: Optional[str] = Field(None, description="关键事件")
    topics: list[str] = Field(default_factory=list, description="讨论话题")
    subtext: Optional[str] = Field(None, description="潜台词分析")
    red_flags: list[str] = Field(default_factory=list, description="危险信号")
    green_flags: list[str] = Field(default_factory=list, description="积极信号")


class MemoryResponse(BaseModel):
    """记忆响应"""

    model_config = ConfigDict(from_attributes=True)

    id: UUID
    target_id: UUID
    happened_at: datetime
    source_type: str
    content: Optional[str]
    image_url: Optional[str]
    extracted_facts: dict[str, Any]
    sentiment_score: int
    created_at: datetime


class MemoryListResponse(BaseModel):
    """记忆列表响应"""

    total: int
    items: list[MemoryResponse]


# ========================
# Upload & AI Analysis Schemas
# ========================


class ProfileUpdate(BaseModel):
    """AI 提取的档案更新"""

    tags_to_add: list[str] = Field(default_factory=list, description="新增标签")
    mbti: Optional[str] = None
    zodiac: Optional[str] = None
    age_range: Optional[str] = None
    occupation: Optional[str] = None
    location: Optional[str] = None
    appearance_updates: Optional[dict[str, Any]] = None
    personality_updates: Optional[dict[str, Any]] = None
    likes_to_add: list[str] = Field(default_factory=list, description="新增喜好")
    dislikes_to_add: list[str] = Field(default_factory=list, description="新增厌恶")


class NewMemory(BaseModel):
    """AI 提取的新记忆"""

    happened_at: Optional[datetime] = Field(None, description="事件时间 (如能推断)")
    content_summary: str = Field(..., description="内容摘要")
    sentiment: str = Field(..., description="情绪类型")
    sentiment_score: int = Field(0, ge=-10, le=10, description="情绪评分")
    key_event: Optional[str] = None
    topics: list[str] = Field(default_factory=list)
    subtext: Optional[str] = Field(None, description="潜台词分析")
    red_flags: list[str] = Field(default_factory=list)
    green_flags: list[str] = Field(default_factory=list)
    conversation_fingerprint: Optional[str] = Field(None, description="对话指纹用于去重")


class AIAnalysisResult(BaseModel):
    """AI 分析结果"""

    image_type: str = Field(..., description="图片类型: wechat, tantan, soul, xiaohongshu, photo, unknown")
    confidence: float = Field(..., ge=0, le=1, description="置信度")
    profile_updates: ProfileUpdate = Field(default_factory=ProfileUpdate, description="档案更新")
    new_memories: list[NewMemory] = Field(default_factory=list, description="新记忆列表")
    raw_text_extracted: Optional[str] = Field(None, description="原始提取文本")
    analysis_notes: Optional[str] = Field(None, description="分析备注")


class UploadRequest(BaseModel):
    """上传请求 (表单数据，实际由 Form 处理)"""

    target_id: UUID = Field(..., description="关联的对象 ID")


class UploadResponse(BaseModel):
    """上传响应"""

    success: bool
    message: str
    image_url: Optional[str] = None
    analysis_result: Optional[AIAnalysisResult] = None
    memories_created: int = 0
    profile_updated: bool = False


# ========================
# 通用响应 Schemas
# ========================


class MessageResponse(BaseModel):
    """通用消息响应"""

    success: bool
    message: str


class ErrorResponse(BaseModel):
    """错误响应"""

    detail: str
    error_code: Optional[str] = None

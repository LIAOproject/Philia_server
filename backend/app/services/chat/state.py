"""
Philia Chat - 状态定义

定义 LangGraph 工作流的状态结构
"""

from datetime import datetime
from typing import Annotated, Optional
from uuid import UUID

from pydantic import BaseModel, Field
from typing_extensions import TypedDict


class TargetProfileSummary(BaseModel):
    """对象档案摘要 (传递给 AI 的精简版本)"""

    id: UUID
    name: str
    current_status: Optional[str] = None
    profile_summary: str = ""  # 标签、MBTI、星座等
    preferences: str = ""  # 喜好摘要
    ai_summary: Optional[str] = None


class MentorConfig(BaseModel):
    """导师配置"""

    id: UUID
    name: str
    style_tag: Optional[str] = None
    system_prompt_template: str


class RetrievedMemory(BaseModel):
    """检索到的记忆"""

    id: Optional[UUID] = None
    content: str
    happened_at: datetime
    source_type: str
    sentiment_score: int = 0
    relevance_score: float = 0.0


class ChatMessage(BaseModel):
    """对话消息"""

    role: str  # "user" | "assistant"
    content: str


class RAGConfig(BaseModel):
    """RAG 配置"""

    enabled: bool = True
    max_memories: int = 5
    max_recent_messages: int = 10
    time_decay_factor: float = 0.1
    min_relevance_score: float = 0.35  # 综合评分门槛（向量相似度*0.8 + 时间因子*0.2）
    min_similarity: float = 0.5  # 向量相似度门槛


class AgentState(TypedDict):
    """
    LangGraph Agent 状态

    包含整个对话流程中需要传递的所有信息

    Attributes:
        chatbot_id: Chatbot 会话 ID
        target_profile: 对象档案信息
        mentor_config: 导师配置
        rag_config: RAG 配置
        rag_corpus: 自定义语料库

        user_message: 当前用户消息
        recent_messages: 最近的对话历史
        retrieved_memories: RAG 检索到的记忆

        route_decision: 路由决策 ("mentor_chat" | "memory_rag")
        generation: AI 生成的回复
        needs_fact_extraction: 是否需要提取新事实

        error: 错误信息 (如果有)
    """

    # 会话配置
    chatbot_id: UUID
    target_id: UUID
    target_profile: TargetProfileSummary
    mentor_config: MentorConfig
    rag_config: RAGConfig
    rag_corpus: list[dict]  # 自定义语料库 [{"content": "..."}]

    # 输入
    user_message: str
    recent_messages: list[ChatMessage]

    # 中间状态
    retrieved_memories: list[RetrievedMemory]
    route_decision: str  # "mentor_chat" | "memory_rag"

    # 输出
    generation: str
    needs_fact_extraction: bool

    # 错误处理
    error: Optional[str]

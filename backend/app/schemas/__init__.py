# Schemas module - Pydantic 数据模型
from app.schemas.relationship import (
    TargetCreate,
    TargetUpdate,
    TargetResponse,
    TargetListResponse,
    MemoryResponse,
    UploadResponse,
    AIAnalysisResult,
)
from app.schemas.chat import (
    AIMentorCreate,
    AIMentorUpdate,
    AIMentorResponse,
    AIMentorListResponse,
    ChatbotCreate,
    ChatbotUpdate,
    ChatbotResponse,
    ChatbotListResponse,
    ChatbotDetailResponse,
    ChatMessageResponse,
    ChatMessageListResponse,
    SendMessageRequest,
    SendMessageResponse,
)

__all__ = [
    # Relationship
    "TargetCreate",
    "TargetUpdate",
    "TargetResponse",
    "TargetListResponse",
    "MemoryResponse",
    "UploadResponse",
    "AIAnalysisResult",
    # Chat
    "AIMentorCreate",
    "AIMentorUpdate",
    "AIMentorResponse",
    "AIMentorListResponse",
    "ChatbotCreate",
    "ChatbotUpdate",
    "ChatbotResponse",
    "ChatbotListResponse",
    "ChatbotDetailResponse",
    "ChatMessageResponse",
    "ChatMessageListResponse",
    "SendMessageRequest",
    "SendMessageResponse",
]

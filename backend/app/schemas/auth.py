"""
Philia 认证相关的 Pydantic Schema
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


# ==================== 请求 Schema ====================


class DeviceAuthRequest(BaseModel):
    """设备认证请求 (游客模式)"""

    device_id: str = Field(
        ...,
        min_length=10,
        max_length=128,
        description="设备唯一标识符 (iOS identifierForVendor)",
    )


class AppleAuthRequest(BaseModel):
    """Apple Sign In 认证请求"""

    identity_token: str = Field(
        ...,
        description="Apple Sign In 返回的 identity token (JWT)",
    )
    authorization_code: str = Field(
        ...,
        description="Apple Sign In 返回的 authorization code",
    )
    user_identifier: str = Field(
        ...,
        description="Apple Sign In 返回的 user identifier",
    )
    email: Optional[EmailStr] = Field(
        None,
        description="用户邮箱 (可能是隐藏邮箱，首次登录时返回)",
    )
    full_name: Optional[str] = Field(
        None,
        description="用户全名 (首次登录时返回)",
    )
    device_id: str = Field(
        ...,
        min_length=10,
        max_length=128,
        description="设备唯一标识符 (用于关联/合并游客账号)",
    )


class LinkAppleRequest(BaseModel):
    """游客账号绑定 Apple ID 请求"""

    identity_token: str = Field(
        ...,
        description="Apple Sign In 返回的 identity token (JWT)",
    )
    authorization_code: str = Field(
        ...,
        description="Apple Sign In 返回的 authorization code",
    )
    user_identifier: str = Field(
        ...,
        description="Apple Sign In 返回的 user identifier",
    )
    email: Optional[EmailStr] = Field(
        None,
        description="用户邮箱",
    )
    full_name: Optional[str] = Field(
        None,
        description="用户全名",
    )


# ==================== 响应 Schema ====================


class UserResponse(BaseModel):
    """用户信息响应"""

    id: UUID
    device_id: str
    apple_id: Optional[str] = None
    email: Optional[str] = None
    nickname: Optional[str] = None
    avatar_url: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime
    last_login_at: Optional[datetime] = None

    # 是否已绑定 Apple ID
    is_apple_linked: bool = False

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """认证响应"""

    success: bool = True
    message: str
    user: UserResponse
    # 简单 token (MVP 阶段使用 user_id 作为 token)
    # 生产环境应使用 JWT
    access_token: str
    token_type: str = "Bearer"


class AuthErrorResponse(BaseModel):
    """认证错误响应"""

    success: bool = False
    message: str
    error_code: str


# ==================== 通用 Schema ====================


class MessageResponse(BaseModel):
    """通用消息响应"""

    success: bool
    message: str

"""
Philia API - 用户认证路由
支持设备ID登录和Apple ID登录
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.user import User
from app.schemas.auth import (
    AppleAuthRequest,
    AuthResponse,
    DeviceAuthRequest,
    LinkAppleRequest,
    MessageResponse,
    UserResponse,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


# ==================== 辅助函数 ====================


def create_user_response(user: User) -> UserResponse:
    """创建用户响应对象"""
    return UserResponse(
        id=user.id,
        device_id=user.device_id,
        apple_id=user.apple_id,
        email=user.email,
        nickname=user.nickname,
        avatar_url=user.avatar_url,
        status=user.status,
        created_at=user.created_at,
        updated_at=user.updated_at,
        last_login_at=user.last_login_at,
        is_apple_linked=user.apple_id is not None,
    )


async def get_current_user(
    authorization: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    获取当前登录用户
    从 Authorization header 中提取 token (user_id)
    """
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="未提供认证信息",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 解析 Bearer token
    try:
        scheme, token = authorization.split()
        if scheme.lower() != "bearer":
            raise ValueError("Invalid scheme")
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的认证格式",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # MVP: token 就是 user_id
    try:
        user_id = UUID(token)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的 token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 查询用户
    query = select(User).where(User.id == user_id, User.status == "active")
    result = await db.execute(query)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在或已禁用",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return user


# ==================== API 端点 ====================


@router.post("/device", response_model=AuthResponse)
async def auth_with_device(
    request: DeviceAuthRequest,
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """
    设备认证 (游客模式)

    - 如果设备已注册，返回现有用户
    - 如果设备未注册，自动创建新用户

    **请求参数:**
    - **device_id**: iOS identifierForVendor 或其他设备唯一标识
    """
    # 查找现有用户
    query = select(User).where(User.device_id == request.device_id)
    result = await db.execute(query)
    user = result.scalar_one_or_none()

    if user:
        # 更新最后登录时间
        user.last_login_at = datetime.utcnow()
        await db.commit()
        await db.refresh(user)

        return AuthResponse(
            success=True,
            message="登录成功",
            user=create_user_response(user),
            access_token=str(user.id),
            token_type="Bearer",
        )

    # 创建新用户 (游客)
    user = User(
        device_id=request.device_id,
        status="active",
        last_login_at=datetime.utcnow(),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return AuthResponse(
        success=True,
        message="账号创建成功",
        user=create_user_response(user),
        access_token=str(user.id),
        token_type="Bearer",
    )


@router.post("/apple", response_model=AuthResponse)
async def auth_with_apple(
    request: AppleAuthRequest,
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """
    Apple Sign In 认证

    - 如果 Apple ID 已绑定用户，返回该用户
    - 如果 Apple ID 未绑定但设备有游客账号，自动绑定
    - 如果都没有，创建新用户

    **请求参数:**
    - **identity_token**: Apple 返回的 JWT token
    - **authorization_code**: Apple 返回的授权码
    - **user_identifier**: Apple 用户标识符
    - **email**: 用户邮箱 (可选，首次登录时返回)
    - **full_name**: 用户全名 (可选，首次登录时返回)
    - **device_id**: 设备标识符 (用于关联游客账号)
    """
    # TODO: 生产环境需要验证 identity_token
    # 1. 从 Apple 获取公钥
    # 2. 验证 JWT 签名
    # 3. 验证 token 的 aud, iss, exp 等字段

    # 查找已绑定 Apple ID 的用户
    query = select(User).where(User.apple_id == request.user_identifier)
    result = await db.execute(query)
    existing_apple_user = result.scalar_one_or_none()

    if existing_apple_user:
        # Apple ID 已绑定，直接登录
        existing_apple_user.last_login_at = datetime.utcnow()
        await db.commit()
        await db.refresh(existing_apple_user)

        return AuthResponse(
            success=True,
            message="Apple 登录成功",
            user=create_user_response(existing_apple_user),
            access_token=str(existing_apple_user.id),
            token_type="Bearer",
        )

    # 查找设备对应的游客账号
    query = select(User).where(User.device_id == request.device_id)
    result = await db.execute(query)
    device_user = result.scalar_one_or_none()

    if device_user:
        # 游客账号存在，绑定 Apple ID
        device_user.apple_id = request.user_identifier
        if request.email:
            device_user.email = request.email
        if request.full_name:
            device_user.nickname = request.full_name
        device_user.last_login_at = datetime.utcnow()
        await db.commit()
        await db.refresh(device_user)

        return AuthResponse(
            success=True,
            message="Apple ID 已绑定到现有账号",
            user=create_user_response(device_user),
            access_token=str(device_user.id),
            token_type="Bearer",
        )

    # 创建新用户
    user = User(
        device_id=request.device_id,
        apple_id=request.user_identifier,
        email=request.email,
        nickname=request.full_name,
        status="active",
        last_login_at=datetime.utcnow(),
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)

    return AuthResponse(
        success=True,
        message="Apple 账号创建成功",
        user=create_user_response(user),
        access_token=str(user.id),
        token_type="Bearer",
    )


@router.post("/link-apple", response_model=AuthResponse)
async def link_apple_id(
    request: LinkAppleRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    """
    游客账号绑定 Apple ID

    需要已登录 (携带 Authorization header)

    **请求参数:**
    - **identity_token**: Apple 返回的 JWT token
    - **authorization_code**: Apple 返回的授权码
    - **user_identifier**: Apple 用户标识符
    - **email**: 用户邮箱 (可选)
    - **full_name**: 用户全名 (可选)
    """
    # 检查是否已绑定
    if current_user.apple_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="该账号已绑定 Apple ID",
        )

    # 检查 Apple ID 是否已被其他账号使用
    query = select(User).where(User.apple_id == request.user_identifier)
    result = await db.execute(query)
    existing_user = result.scalar_one_or_none()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="该 Apple ID 已被其他账号绑定",
        )

    # 绑定 Apple ID
    current_user.apple_id = request.user_identifier
    if request.email:
        current_user.email = request.email
    if request.full_name:
        current_user.nickname = request.full_name

    await db.commit()
    await db.refresh(current_user)

    return AuthResponse(
        success=True,
        message="Apple ID 绑定成功",
        user=create_user_response(current_user),
        access_token=str(current_user.id),
        token_type="Bearer",
    )


@router.get("/me", response_model=UserResponse)
async def get_current_user_info(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    """
    获取当前登录用户信息

    需要携带 Authorization header
    """
    return create_user_response(current_user)


@router.delete("/me", response_model=MessageResponse)
async def delete_account(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    """
    删除当前账号

    会级联删除所有关联的 Targets、Chatbots 等数据

    **警告**: 此操作不可逆
    """
    # 软删除：设置状态为 deleted
    current_user.status = "deleted"
    await db.commit()

    return MessageResponse(
        success=True,
        message="账号已删除",
    )

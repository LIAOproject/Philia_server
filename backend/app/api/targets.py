"""
Relation-OS API - 关系对象 (Targets) 路由
CRUD 操作
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.relationship import TargetMemory, TargetProfile
from app.schemas.relationship import (
    MessageResponse,
    TargetCreate,
    TargetListResponse,
    TargetResponse,
    TargetUpdate,
)

router = APIRouter(prefix="/targets", tags=["Targets"])


@router.post("/", response_model=TargetResponse, status_code=status.HTTP_201_CREATED)
async def create_target(
    target_data: TargetCreate,
    db: AsyncSession = Depends(get_db),
) -> TargetResponse:
    """
    创建新的关系对象

    - **name**: 对象名称 (必填)
    - **avatar_url**: 头像 URL
    - **current_status**: 当前关系状态
    - **profile_data**: 画像数据 (JSONB)
    - **preferences**: 喜好数据 (JSONB)
    """
    # 创建模型实例
    target = TargetProfile(
        name=target_data.name,
        avatar_url=target_data.avatar_url,
        current_status=target_data.current_status,
        profile_data=target_data.profile_data or {},
        preferences=target_data.preferences or {"likes": [], "dislikes": []},
    )

    db.add(target)
    await db.commit()
    await db.refresh(target)

    return TargetResponse(
        id=target.id,
        name=target.name,
        avatar_url=target.avatar_url,
        current_status=target.current_status,
        profile_data=target.profile_data,
        preferences=target.preferences,
        ai_summary=target.ai_summary,
        created_at=target.created_at,
        updated_at=target.updated_at,
        memory_count=0,
    )


@router.get("/", response_model=TargetListResponse)
async def list_targets(
    skip: int = Query(0, ge=0, description="跳过记录数"),
    limit: int = Query(20, ge=1, le=100, description="返回记录数"),
    status_filter: Optional[str] = Query(None, description="按状态筛选"),
    db: AsyncSession = Depends(get_db),
) -> TargetListResponse:
    """
    获取关系对象列表

    支持分页和状态筛选
    """
    # 构建查询
    query = select(TargetProfile)

    if status_filter:
        query = query.where(TargetProfile.current_status == status_filter)

    # 统计总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页查询
    query = query.order_by(TargetProfile.updated_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    targets = result.scalars().all()

    # 统计每个对象的记忆数量
    items = []
    for target in targets:
        memory_count_query = select(func.count()).where(
            TargetMemory.target_id == target.id
        )
        memory_count_result = await db.execute(memory_count_query)
        memory_count = memory_count_result.scalar() or 0

        items.append(
            TargetResponse(
                id=target.id,
                name=target.name,
                avatar_url=target.avatar_url,
                current_status=target.current_status,
                profile_data=target.profile_data,
                preferences=target.preferences,
                ai_summary=target.ai_summary,
                created_at=target.created_at,
                updated_at=target.updated_at,
                memory_count=memory_count,
            )
        )

    return TargetListResponse(total=total, items=items)


@router.get("/{target_id}", response_model=TargetResponse)
async def get_target(
    target_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> TargetResponse:
    """
    获取单个关系对象详情
    """
    query = select(TargetProfile).where(TargetProfile.id == target_id)
    result = await db.execute(query)
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"对象 {target_id} 不存在",
        )

    # 统计记忆数量
    memory_count_query = select(func.count()).where(
        TargetMemory.target_id == target.id
    )
    memory_count_result = await db.execute(memory_count_query)
    memory_count = memory_count_result.scalar() or 0

    return TargetResponse(
        id=target.id,
        name=target.name,
        avatar_url=target.avatar_url,
        current_status=target.current_status,
        profile_data=target.profile_data,
        preferences=target.preferences,
        ai_summary=target.ai_summary,
        created_at=target.created_at,
        updated_at=target.updated_at,
        memory_count=memory_count,
    )


@router.patch("/{target_id}", response_model=TargetResponse)
async def update_target(
    target_id: UUID,
    target_data: TargetUpdate,
    db: AsyncSession = Depends(get_db),
) -> TargetResponse:
    """
    更新关系对象

    支持部分更新
    """
    query = select(TargetProfile).where(TargetProfile.id == target_id)
    result = await db.execute(query)
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"对象 {target_id} 不存在",
        )

    # 更新字段
    update_data = target_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(target, field, value)

    await db.commit()
    await db.refresh(target)

    # 统计记忆数量
    memory_count_query = select(func.count()).where(
        TargetMemory.target_id == target.id
    )
    memory_count_result = await db.execute(memory_count_query)
    memory_count = memory_count_result.scalar() or 0

    return TargetResponse(
        id=target.id,
        name=target.name,
        avatar_url=target.avatar_url,
        current_status=target.current_status,
        profile_data=target.profile_data,
        preferences=target.preferences,
        ai_summary=target.ai_summary,
        created_at=target.created_at,
        updated_at=target.updated_at,
        memory_count=memory_count,
    )


@router.delete("/{target_id}", response_model=MessageResponse)
async def delete_target(
    target_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    """
    删除关系对象

    会级联删除所有关联的记忆
    """
    query = select(TargetProfile).where(TargetProfile.id == target_id)
    result = await db.execute(query)
    target = result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"对象 {target_id} 不存在",
        )

    await db.delete(target)
    await db.commit()

    return MessageResponse(
        success=True,
        message=f"对象 {target.name} 已删除",
    )

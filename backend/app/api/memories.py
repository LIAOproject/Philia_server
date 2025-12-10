"""
Relation-OS API - 记忆 (Memories) 路由
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.relationship import TargetMemory, TargetProfile
from app.schemas.relationship import (
    MemoryListResponse,
    MemoryResponse,
    MessageResponse,
)

router = APIRouter(prefix="/memories", tags=["Memories"])


@router.get("/", response_model=MemoryListResponse)
async def list_memories(
    target_id: Optional[UUID] = Query(None, description="按对象 ID 筛选"),
    source_type: Optional[str] = Query(None, description="按来源类型筛选"),
    skip: int = Query(0, ge=0, description="跳过记录数"),
    limit: int = Query(50, ge=1, le=200, description="返回记录数"),
    db: AsyncSession = Depends(get_db),
) -> MemoryListResponse:
    """
    获取记忆列表

    支持按对象 ID 和来源类型筛选
    """
    # 构建查询
    query = select(TargetMemory)

    if target_id:
        query = query.where(TargetMemory.target_id == target_id)

    if source_type:
        query = query.where(TargetMemory.source_type == source_type)

    # 统计总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页查询 (按事件时间倒序)
    query = query.order_by(TargetMemory.happened_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    memories = result.scalars().all()

    items = [
        MemoryResponse(
            id=memory.id,
            target_id=memory.target_id,
            happened_at=memory.happened_at,
            source_type=memory.source_type,
            content=memory.content,
            image_url=memory.image_url,
            extracted_facts=memory.extracted_facts,
            sentiment_score=memory.sentiment_score,
            created_at=memory.created_at,
        )
        for memory in memories
    ]

    return MemoryListResponse(total=total, items=items)


@router.get("/{memory_id}", response_model=MemoryResponse)
async def get_memory(
    memory_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> MemoryResponse:
    """
    获取单个记忆详情
    """
    query = select(TargetMemory).where(TargetMemory.id == memory_id)
    result = await db.execute(query)
    memory = result.scalar_one_or_none()

    if not memory:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"记忆 {memory_id} 不存在",
        )

    return MemoryResponse(
        id=memory.id,
        target_id=memory.target_id,
        happened_at=memory.happened_at,
        source_type=memory.source_type,
        content=memory.content,
        image_url=memory.image_url,
        extracted_facts=memory.extracted_facts,
        sentiment_score=memory.sentiment_score,
        created_at=memory.created_at,
    )


@router.delete("/{memory_id}", response_model=MessageResponse)
async def delete_memory(
    memory_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    """
    删除记忆
    """
    query = select(TargetMemory).where(TargetMemory.id == memory_id)
    result = await db.execute(query)
    memory = result.scalar_one_or_none()

    if not memory:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"记忆 {memory_id} 不存在",
        )

    await db.delete(memory)
    await db.commit()

    return MessageResponse(
        success=True,
        message="记忆已删除",
    )


@router.get("/target/{target_id}/timeline", response_model=MemoryListResponse)
async def get_target_timeline(
    target_id: UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: AsyncSession = Depends(get_db),
) -> MemoryListResponse:
    """
    获取指定对象的时间轴

    按事件时间排序的完整记忆列表
    """
    # 验证 target 存在
    target_query = select(TargetProfile).where(TargetProfile.id == target_id)
    target_result = await db.execute(target_query)
    target = target_result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"对象 {target_id} 不存在",
        )

    # 查询记忆
    query = (
        select(TargetMemory)
        .where(TargetMemory.target_id == target_id)
        .order_by(TargetMemory.happened_at.asc())
        .offset(skip)
        .limit(limit)
    )

    # 统计总数
    count_query = select(func.count()).where(TargetMemory.target_id == target_id)
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    result = await db.execute(query)
    memories = result.scalars().all()

    items = [
        MemoryResponse(
            id=memory.id,
            target_id=memory.target_id,
            happened_at=memory.happened_at,
            source_type=memory.source_type,
            content=memory.content,
            image_url=memory.image_url,
            extracted_facts=memory.extracted_facts,
            sentiment_score=memory.sentiment_score,
            created_at=memory.created_at,
        )
        for memory in memories
    ]

    return MemoryListResponse(total=total, items=items)

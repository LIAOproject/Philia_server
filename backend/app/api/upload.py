"""
Relation-OS API - 图片上传与 AI 分析路由
核心功能: 接收图片 -> 调用豆包 Vision -> 更新档案
"""

import hashlib
import os
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.relationship import TargetMemory, TargetProfile
from app.schemas.relationship import AIAnalysisResult, UploadResponse
from app.services.embedding_service import get_embedding
from app.services.memory_dedup_service import check_duplicate_memory
from app.services.memory_conflict_service import handle_memory_conflict
from app.utils.ai_client import analyze_image_with_doubao

router = APIRouter(prefix="/upload", tags=["Upload"])


def _compute_content_hash(content: str) -> str:
    """计算内容哈希用于去重"""
    return hashlib.md5(content.encode()).hexdigest()


def _merge_profile_data(existing: dict, updates: dict) -> dict:
    """
    合并档案数据
    - 标签: 去重追加
    - 其他字段: 新值覆盖旧值 (如果新值非空)
    """
    merged = existing.copy()

    # 合并标签 (去重)
    existing_tags = set(merged.get("tags", []))
    new_tags = set(updates.get("tags_to_add", []))
    merged["tags"] = list(existing_tags | new_tags)

    # 合并其他字段
    for field in ["mbti", "zodiac", "age_range", "occupation", "location", "education"]:
        if updates.get(field):
            merged[field] = updates[field]

    # 合并外貌特征
    if updates.get("appearance_updates"):
        merged["appearance"] = {
            **merged.get("appearance", {}),
            **updates["appearance_updates"],
        }

    # 合并性格特征
    if updates.get("personality_updates"):
        merged["personality"] = {
            **merged.get("personality", {}),
            **updates["personality_updates"],
        }

    return merged


def _merge_preferences(existing: dict, updates: dict) -> dict:
    """合并喜好数据"""
    merged = existing.copy()

    # 合并 likes
    existing_likes = set(merged.get("likes", []))
    new_likes = set(updates.get("likes_to_add", []))
    merged["likes"] = list(existing_likes | new_likes)

    # 合并 dislikes
    existing_dislikes = set(merged.get("dislikes", []))
    new_dislikes = set(updates.get("dislikes_to_add", []))
    merged["dislikes"] = list(existing_dislikes | new_dislikes)

    return merged


async def _save_upload_file(file: UploadFile, target_id: uuid.UUID) -> str:
    """
    保存上传的文件到本地

    Returns:
        文件相对路径
    """
    # 确保上传目录存在
    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)

    # 生成唯一文件名
    file_ext = os.path.splitext(file.filename)[1] if file.filename else ".jpg"
    unique_filename = f"{target_id}_{uuid.uuid4().hex[:8]}{file_ext}"
    file_path = os.path.join(upload_dir, unique_filename)

    # 保存文件
    content = await file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    # 重置文件指针 (后续还要读取进行 AI 分析)
    await file.seek(0)

    return f"/uploads/{unique_filename}"


@router.post("/analyze", response_model=UploadResponse)
async def upload_and_analyze(
    file: UploadFile = File(..., description="图片文件"),
    target_id: str = Form(..., description="关联的对象 ID"),
    source_type: Optional[str] = Form(None, description="来源类型（可选，不传则使用 AI 识别的类型）"),
    happened_at: Optional[str] = Form(None, description="事件时间 (ISO 格式)"),
    db: AsyncSession = Depends(get_db),
) -> UploadResponse:
    """
    上传图片并使用 AI 分析

    ## 处理流程:
    1. 验证文件类型和大小
    2. 保存图片到本地
    3. 调用豆包 Vision 模型分析
    4. 更新对象档案 (profile_data)
    5. 创建新的记忆记录

    ## 参数:
    - **file**: 图片文件 (支持 png/jpg/jpeg/gif/webp)
    - **target_id**: 关联的关系对象 ID
    - **source_type**: 来源类型 (wechat/qq/tantan/soul/xiaohongshu/photo)
    - **happened_at**: 事件发生时间 (可选，默认当前时间)
    """
    # 解析 target_id
    try:
        target_uuid = uuid.UUID(target_id)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="无效的 target_id 格式",
        )

    # 验证 target 存在
    target_query = select(TargetProfile).where(TargetProfile.id == target_uuid)
    target_result = await db.execute(target_query)
    target = target_result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"对象 {target_id} 不存在",
        )

    # 验证文件类型
    if file.content_type:
        mime_type = file.content_type.lower()
        if not mime_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只支持图片文件",
            )

    # 验证文件扩展名
    if file.filename:
        ext = file.filename.rsplit(".", 1)[-1].lower()
        if ext not in settings.ALLOWED_EXTENSIONS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"不支持的文件类型: {ext}",
            )

    # 读取文件内容
    image_bytes = await file.read()

    # 验证文件大小
    if len(image_bytes) > settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"文件过大，最大支持 {settings.MAX_FILE_SIZE // 1024 // 1024}MB",
        )

    # 保存文件
    await file.seek(0)
    image_url = await _save_upload_file(file, target_uuid)
    logger.info(f"图片已保存: {image_url}")

    # 调用 AI 分析
    try:
        analysis_result: AIAnalysisResult = await analyze_image_with_doubao(image_bytes)
        logger.info(f"AI 分析完成: {analysis_result.image_type}, 置信度: {analysis_result.confidence}")
    except Exception as e:
        logger.error(f"AI 分析失败: {e}")
        # 即使 AI 分析失败，也保存基础记录
        analysis_result = AIAnalysisResult(
            image_type="unknown",
            confidence=0.0,
            analysis_notes=f"AI 分析失败: {str(e)}",
        )

    # 更新对象档案
    profile_updated = False
    if analysis_result.profile_updates:
        updates = analysis_result.profile_updates.model_dump()

        # 合并 profile_data
        new_profile = _merge_profile_data(target.profile_data, updates)
        if new_profile != target.profile_data:
            target.profile_data = new_profile
            profile_updated = True

        # 合并 preferences
        new_preferences = _merge_preferences(target.preferences, updates)
        if new_preferences != target.preferences:
            target.preferences = new_preferences
            profile_updated = True

    # 创建记忆记录
    memories_created = 0

    # 解析事件时间
    event_time = datetime.now(timezone.utc)
    if happened_at:
        try:
            event_time = datetime.fromisoformat(happened_at.replace("Z", "+00:00"))
        except ValueError:
            pass

    for new_memory in analysis_result.new_memories:
        # 使用 AI 提取的时间，或使用用户指定的时间
        memory_time = new_memory.happened_at or event_time

        # 计算内容哈希用于去重
        content_hash = None
        if new_memory.conversation_fingerprint:
            content_hash = _compute_content_hash(new_memory.conversation_fingerprint)

            # 检查是否重复
            existing_query = select(TargetMemory).where(
                TargetMemory.target_id == target_uuid,
                TargetMemory.content_hash == content_hash,
            )
            existing_result = await db.execute(existing_query)
            if existing_result.scalar_one_or_none():
                logger.info(f"跳过重复记忆: {content_hash}")
                continue

        # 生成记忆内容的向量嵌入
        memory_embedding = None
        conflict_info = None
        if new_memory.content_summary:
            memory_embedding = get_embedding(new_memory.content_summary)

            # 语义去重检查：检查是否已存在高度相似的记忆
            is_duplicate, existing_id, similarity = await check_duplicate_memory(
                db=db,
                target_id=target_uuid,
                content=new_memory.content_summary,
                embedding=memory_embedding,
            )

            if is_duplicate:
                logger.info(
                    f"跳过语义重复记忆 (相似度={similarity:.4f}): "
                    f"'{new_memory.content_summary[:50]}...' 已存在记忆 {existing_id}"
                )
                continue

            # 冲突检测：检查是否与已有记忆冲突
            conflict_info = await handle_memory_conflict(
                db=db,
                target_id=target_uuid,
                new_content=new_memory.content_summary,
                embedding=memory_embedding,
            )

        # 构建 extracted_facts
        extracted_facts = {
            "sentiment": new_memory.sentiment,
            "key_event": new_memory.key_event,
            "topics": new_memory.topics,
            "subtext": new_memory.subtext,
            "red_flags": new_memory.red_flags,
            "green_flags": new_memory.green_flags,
        }

        # 如果存在冲突，记录被替代的记忆ID
        if memory_embedding and conflict_info:
            extracted_facts["replaced_memory_id"] = conflict_info["replaced_memory_id"]
            logger.info(f"新记忆替代了旧记忆: {conflict_info['replaced_memory_id']}")

        # 创建记忆
        memory = TargetMemory(
            target_id=target_uuid,
            happened_at=memory_time,
            source_type=source_type or analysis_result.image_type,
            content=new_memory.content_summary,
            image_url=image_url,
            extracted_facts=extracted_facts,
            sentiment_score=new_memory.sentiment_score,
            content_hash=content_hash,
            embedding=memory_embedding,
        )

        db.add(memory)
        memories_created += 1

    # 如果没有从 AI 提取到记忆，但图片成功上传，创建一个基础记录
    if memories_created == 0:
        fallback_content = analysis_result.raw_text_extracted or "图片上传"
        fallback_embedding = get_embedding(fallback_content)

        # 对 fallback 记忆也做去重检查
        is_duplicate, existing_id, similarity = await check_duplicate_memory(
            db=db,
            target_id=target_uuid,
            content=fallback_content,
            embedding=fallback_embedding,
        )

        if not is_duplicate:
            # 冲突检测
            fallback_conflict_info = await handle_memory_conflict(
                db=db,
                target_id=target_uuid,
                new_content=fallback_content,
                embedding=fallback_embedding,
            )

            # 构建 extracted_facts
            fallback_extracted_facts = {
                "image_type": analysis_result.image_type,
                "notes": analysis_result.analysis_notes,
            }

            if fallback_conflict_info:
                fallback_extracted_facts["replaced_memory_id"] = fallback_conflict_info["replaced_memory_id"]
                logger.info(f"Fallback 记忆替代了旧记忆: {fallback_conflict_info['replaced_memory_id']}")

            memory = TargetMemory(
                target_id=target_uuid,
                happened_at=event_time,
                source_type=source_type or "photo",
                content=fallback_content,
                image_url=image_url,
                extracted_facts=fallback_extracted_facts,
                sentiment_score=0,
                embedding=fallback_embedding,
            )
            db.add(memory)
            memories_created = 1
        else:
            logger.info(
                f"跳过 fallback 重复记忆 (相似度={similarity:.4f}): "
                f"'{fallback_content[:50]}...' 已存在记忆 {existing_id}"
            )

    # 提交数据库更改
    await db.commit()

    return UploadResponse(
        success=True,
        message="图片上传并分析完成",
        image_url=image_url,
        analysis_result=analysis_result,
        memories_created=memories_created,
        profile_updated=profile_updated,
    )


@router.post("/analyze-only", response_model=AIAnalysisResult)
async def analyze_image_only(
    file: UploadFile = File(..., description="图片文件"),
) -> AIAnalysisResult:
    """
    仅分析图片，不保存数据

    用于预览 AI 分析结果
    """
    # 验证文件类型
    if file.content_type:
        mime_type = file.content_type.lower()
        if not mime_type.startswith("image/"):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="只支持图片文件",
            )

    # 读取文件
    image_bytes = await file.read()

    # 验证文件大小
    if len(image_bytes) > settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"文件过大，最大支持 {settings.MAX_FILE_SIZE // 1024 // 1024}MB",
        )

    # 调用 AI 分析
    try:
        result = await analyze_image_with_doubao(image_bytes)
        return result
    except Exception as e:
        logger.error(f"AI 分析失败: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"AI 分析失败: {str(e)}",
        )

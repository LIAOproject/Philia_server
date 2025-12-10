"""
Philia Memory Conflict Detection Service
记忆冲突检测服务：检测并更新冲突的记忆

当新记忆与已有记忆存在语义冲突时，将旧记忆标记为 outdated，
并在新记忆的 extracted_facts 中记录 replaced_memory_id 用于追溯
"""

from typing import Optional
from uuid import UUID

from loguru import logger
from sqlalchemy import text, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.relationship import TargetMemory
from app.services.embedding_service import get_embedding
from app.services.llm_service import get_llm_service

# 冲突检测的相似度阈值：高于此值且被判定为冲突才更新
CONFLICT_SIMILARITY_THRESHOLD = 0.75


async def detect_conflicting_memory(
    db: AsyncSession,
    target_id: UUID,
    new_content: str,
    embedding: Optional[list[float]] = None,
    similarity_threshold: float = CONFLICT_SIMILARITY_THRESHOLD,
) -> tuple[bool, Optional[UUID], Optional[str], Optional[float]]:
    """
    检测是否存在冲突的记忆

    使用两阶段检测：
    1. 向量相似度找出候选记忆
    2. LLM 判断是否存在语义冲突（同一主题的不同/更新信息）

    Args:
        db: 数据库会话
        target_id: Target ID
        new_content: 新记忆内容
        embedding: 新记忆的向量嵌入（可选）
        similarity_threshold: 相似度阈值

    Returns:
        (是否冲突, 冲突记忆ID, 冲突记忆内容, 相似度分数)
    """
    if not new_content or not new_content.strip():
        return False, None, None, None

    # 生成 embedding
    if embedding is None:
        embedding = get_embedding(new_content)

    # 检查零向量
    if all(v == 0.0 for v in embedding[:10]):
        logger.warning("Embedding is zero vector, skipping conflict check")
        return False, None, None, None

    try:
        # 阶段1: 向量相似度检索候选记忆
        # 将 embedding 转换为字符串格式以避免 SQLAlchemy 参数解析问题
        embedding_str = "[" + ",".join(str(v) for v in embedding) + "]"
        result = await db.execute(
            text("""
                SELECT
                    id,
                    content,
                    1 - (embedding <=> CAST(:embedding AS vector)) as similarity
                FROM target_memory
                WHERE target_id = :target_id
                    AND embedding IS NOT NULL
                    AND content IS NOT NULL
                    AND status = 'active'
                    AND 1 - (embedding <=> CAST(:embedding AS vector)) >= :threshold
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT 3
            """),
            {
                "target_id": str(target_id),
                "embedding": embedding_str,
                "threshold": similarity_threshold,
            }
        )

        candidates = result.fetchall()

        if not candidates:
            return False, None, None, None

        # 阶段2: 使用 LLM 判断是否存在冲突
        for memory_id, existing_content, similarity in candidates:
            is_conflict = await _check_conflict_with_llm(new_content, existing_content)

            if is_conflict:
                logger.info(
                    f"Conflict detected (similarity={similarity:.4f}): "
                    f"new='{new_content[:80]}...' conflicts with memory {memory_id}"
                )
                return True, memory_id, existing_content, similarity

        return False, None, None, None

    except Exception as e:
        logger.error(f"Conflict detection failed: {e}")
        return False, None, None, None


async def _check_conflict_with_llm(new_content: str, existing_content: str) -> bool:
    """
    使用 LLM 判断两条记忆是否存在冲突

    冲突定义：关于同一主题/事实的不同或更新的信息
    例如：
    - "她喜欢喝咖啡" vs "她不喜欢咖啡" -> 冲突
    - "她住在北京" vs "她搬到上海了" -> 冲突
    - "她喜欢看电影" vs "她喜欢喝咖啡" -> 不冲突（不同主题）
    """
    prompt = f"""判断以下两条关于同一个人的记忆是否存在冲突。

冲突的定义：两条记忆描述的是同一个主题/事实，但信息不同或有更新。

记忆A（新记忆）：{new_content}

记忆B（已有记忆）：{existing_content}

请只回答 "是" 或 "否"：
- "是"：两条记忆关于同一主题，但信息有冲突或更新
- "否"：两条记忆描述不同的事情，或者信息完全一致

回答："""

    try:
        llm_service = get_llm_service()
        response = llm_service.chat(
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1,
            max_tokens=10,
        )

        answer = response.strip().lower()
        return answer.startswith("是") or "是" in answer[:5]

    except Exception as e:
        logger.error(f"LLM conflict check failed: {e}")
        # 出错时保守处理，不认为是冲突
        return False


async def mark_memory_as_outdated(
    db: AsyncSession,
    memory_id: UUID,
) -> bool:
    """
    将记忆标记为 outdated

    Args:
        db: 数据库会话
        memory_id: 要标记的记忆 ID

    Returns:
        是否成功
    """
    try:
        await db.execute(
            update(TargetMemory)
            .where(TargetMemory.id == memory_id)
            .values(status="outdated")
        )
        await db.commit()

        logger.info(f"Memory {memory_id} marked as outdated")
        return True

    except Exception as e:
        logger.error(f"Failed to mark memory as outdated: {e}")
        await db.rollback()
        return False


async def handle_memory_conflict(
    db: AsyncSession,
    target_id: UUID,
    new_content: str,
    embedding: Optional[list[float]] = None,
) -> Optional[dict]:
    """
    处理记忆冲突的完整流程

    1. 检测是否存在冲突
    2. 如果存在，标记旧记忆为 outdated
    3. 返回冲突信息供调用方使用

    Args:
        db: 数据库会话
        target_id: Target ID
        new_content: 新记忆内容
        embedding: 新记忆的向量嵌入（可选）

    Returns:
        如果存在冲突，返回 {
            "replaced_memory_id": UUID,
            "replaced_content": str,
            "similarity": float
        }
        否则返回 None
    """
    is_conflict, memory_id, existing_content, similarity = await detect_conflicting_memory(
        db=db,
        target_id=target_id,
        new_content=new_content,
        embedding=embedding,
    )

    if not is_conflict or memory_id is None:
        return None

    # 标记旧记忆为 outdated
    success = await mark_memory_as_outdated(db, memory_id)

    if success:
        return {
            "replaced_memory_id": str(memory_id),
            "replaced_content": existing_content,
            "similarity": similarity,
        }

    return None

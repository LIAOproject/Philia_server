"""
Philia Memory Deduplication Service
记忆去重服务：基于语义相似度的记忆去重

在创建新记忆前检查是否已存在高度相似的记忆，避免重复存储
"""

from typing import Optional
from uuid import UUID

from loguru import logger
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.embedding_service import get_embedding

# 相似度阈值：超过此值认为是重复记忆
SIMILARITY_THRESHOLD = 0.92


async def check_duplicate_memory(
    db: AsyncSession,
    target_id: UUID,
    content: str,
    embedding: Optional[list[float]] = None,
    similarity_threshold: float = SIMILARITY_THRESHOLD,
) -> tuple[bool, Optional[UUID], Optional[float]]:
    """
    检查是否存在重复记忆

    使用向量相似度检索，判断是否已有语义高度相似的记忆

    Args:
        db: 数据库会话
        target_id: Target ID
        content: 新记忆内容
        embedding: 新记忆的向量嵌入（可选，如果没有会自动生成）
        similarity_threshold: 相似度阈值 (0-1)

    Returns:
        (是否重复, 重复记忆的ID, 相似度分数)
    """
    if not content or not content.strip():
        return False, None, None

    # 如果没有提供 embedding，生成一个
    if embedding is None:
        embedding = get_embedding(content)

    # 检查 embedding 是否为零向量（生成失败）
    if all(v == 0.0 for v in embedding[:10]):
        logger.warning("Embedding is zero vector, skipping dedup check")
        return False, None, None

    try:
        # 使用 pgvector 的余弦相似度检索
        # 1 - cosine_distance = cosine_similarity
        # 只检查 active 状态的记忆
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
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT 1
            """),
            {
                "target_id": str(target_id),
                "embedding": embedding_str,
            }
        )

        row = result.fetchone()

        if row is None:
            # 没有任何记忆，不是重复
            return False, None, None

        memory_id, existing_content, similarity = row

        logger.debug(
            f"Dedup check: similarity={similarity:.4f}, "
            f"threshold={similarity_threshold}, "
            f"new='{content[:50]}...', "
            f"existing='{existing_content[:50] if existing_content else ''}...'"
        )

        if similarity >= similarity_threshold:
            logger.info(
                f"Duplicate memory detected (similarity={similarity:.4f}): "
                f"'{content[:100]}...' matches existing memory {memory_id}"
            )
            return True, memory_id, similarity

        return False, None, similarity

    except Exception as e:
        logger.error(f"Dedup check failed: {e}")
        # 出错时不阻止创建，返回非重复
        return False, None, None


async def find_similar_memories(
    db: AsyncSession,
    target_id: UUID,
    content: str,
    embedding: Optional[list[float]] = None,
    limit: int = 5,
    min_similarity: float = 0.7,
) -> list[dict]:
    """
    查找相似记忆（用于调试或展示）

    Args:
        db: 数据库会话
        target_id: Target ID
        content: 查询内容
        embedding: 向量嵌入（可选）
        limit: 返回数量
        min_similarity: 最小相似度

    Returns:
        相似记忆列表 [{id, content, similarity}, ...]
    """
    if not content or not content.strip():
        return []

    if embedding is None:
        embedding = get_embedding(content)

    try:
        # 只查找 active 状态的记忆
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
                    AND status = 'active'
                    AND 1 - (embedding <=> CAST(:embedding AS vector)) >= :min_similarity
                ORDER BY embedding <=> CAST(:embedding AS vector)
                LIMIT :limit
            """),
            {
                "target_id": str(target_id),
                "embedding": embedding_str,
                "min_similarity": min_similarity,
                "limit": limit,
            }
        )

        rows = result.fetchall()
        return [
            {
                "id": row[0],
                "content": row[1],
                "similarity": row[2],
            }
            for row in rows
        ]

    except Exception as e:
        logger.error(f"Find similar memories failed: {e}")
        return []

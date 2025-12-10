"""
Migration Script: Backfill embeddings for existing memories
回填脚本：为现有记忆生成向量嵌入

使用方法:
    cd backend
    python -m migrations.002_backfill_embeddings

注意: 需要确保环境变量已正确配置 (ARK_API_KEY, ARK_BASE_URL 等)
"""

import asyncio
import os
import sys

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loguru import logger
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.models.relationship import TargetMemory
from app.services.embedding_service import get_embedding, get_embeddings_batch

# 批处理大小
BATCH_SIZE = 50


async def backfill_embeddings():
    """为所有没有 embedding 的记忆生成向量"""

    # 创建数据库连接
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        # 查询所有没有 embedding 的记忆
        query = select(TargetMemory).where(
            TargetMemory.content.isnot(None),
            TargetMemory.embedding.is_(None),
        )
        result = await db.execute(query)
        memories = result.scalars().all()

        total = len(memories)
        logger.info(f"找到 {total} 条需要生成 embedding 的记忆")

        if total == 0:
            logger.info("无需处理，退出")
            return

        # 分批处理
        processed = 0
        failed = 0

        for i in range(0, total, BATCH_SIZE):
            batch = memories[i : i + BATCH_SIZE]
            texts = [m.content for m in batch]

            try:
                # 批量生成 embeddings
                embeddings = get_embeddings_batch(texts)

                # 更新数据库
                for memory, embedding in zip(batch, embeddings):
                    # 使用原生 SQL 更新 (SQLAlchemy 对 pgvector 类型支持有限)
                    await db.execute(
                        text(
                            """
                            UPDATE target_memory
                            SET embedding = :embedding::vector
                            WHERE id = :memory_id
                            """
                        ),
                        {"memory_id": str(memory.id), "embedding": embedding},
                    )
                    processed += 1

                await db.commit()
                logger.info(f"进度: {processed}/{total} ({processed * 100 // total}%)")

            except Exception as e:
                logger.error(f"批次处理失败: {e}")
                failed += len(batch)
                continue

        logger.info(f"完成! 成功: {processed}, 失败: {failed}")

    await engine.dispose()


if __name__ == "__main__":
    logger.info("开始回填 embeddings...")
    asyncio.run(backfill_embeddings())
    logger.info("回填完成")

"""
Migration Script: Add status field to target_memory table
迁移脚本：为 target_memory 表添加 status 字段

使用方法:
    cd backend
    python -m migrations.003_add_memory_status

字段说明:
    status: 记忆状态
        - 'active': 当前有效的记忆 (默认)
        - 'outdated': 已过时的记忆 (被新记忆替代)

注意: 需要确保环境变量已正确配置 (DATABASE_URL)
"""

import asyncio
import os
import sys

# 添加项目根目录到 Python 路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from loguru import logger
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import settings


async def add_status_field():
    """为 target_memory 表添加 status 字段"""

    # 创建数据库连接
    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        try:
            # 检查字段是否已存在
            check_query = text("""
                SELECT column_name
                FROM information_schema.columns
                WHERE table_name = 'target_memory'
                AND column_name = 'status'
            """)
            result = await db.execute(check_query)
            exists = result.fetchone()

            if exists:
                logger.info("status 字段已存在，跳过迁移")
                return

            # 添加 status 字段
            logger.info("添加 status 字段...")
            await db.execute(text("""
                ALTER TABLE target_memory
                ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'active'
            """))

            # 创建索引
            logger.info("创建 status 索引...")
            await db.execute(text("""
                CREATE INDEX IF NOT EXISTS idx_memory_status
                ON target_memory (status)
            """))

            await db.commit()
            logger.info("迁移成功完成!")

            # 显示统计信息
            stats_query = text("""
                SELECT status, COUNT(*) as count
                FROM target_memory
                GROUP BY status
            """)
            stats_result = await db.execute(stats_query)
            stats = stats_result.fetchall()

            logger.info("记忆状态统计:")
            for status, count in stats:
                logger.info(f"  - {status}: {count} 条")

        except Exception as e:
            logger.error(f"迁移失败: {e}")
            await db.rollback()
            raise

    await engine.dispose()


async def rollback_status_field():
    """回滚：移除 status 字段"""

    engine = create_async_engine(settings.DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as db:
        try:
            logger.info("移除 status 索引...")
            await db.execute(text("""
                DROP INDEX IF EXISTS idx_memory_status
            """))

            logger.info("移除 status 字段...")
            await db.execute(text("""
                ALTER TABLE target_memory
                DROP COLUMN IF EXISTS status
            """))

            await db.commit()
            logger.info("回滚成功!")

        except Exception as e:
            logger.error(f"回滚失败: {e}")
            await db.rollback()
            raise

    await engine.dispose()


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Memory status migration")
    parser.add_argument(
        "--rollback",
        action="store_true",
        help="Rollback the migration (remove status field)",
    )
    args = parser.parse_args()

    if args.rollback:
        logger.info("开始回滚迁移...")
        asyncio.run(rollback_status_field())
    else:
        logger.info("开始迁移：添加 status 字段...")
        asyncio.run(add_status_field())

    logger.info("完成")

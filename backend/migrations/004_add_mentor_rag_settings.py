"""
Migration 004: Add RAG settings to AI Mentor
Adds default_rag_settings and default_rag_corpus columns to ai_mentor table
"""

import asyncio
from sqlalchemy import text
from app.core.database import engine


async def run_migration():
    """Add RAG settings columns to ai_mentor table"""

    async with engine.begin() as conn:
        # Check if columns already exist
        check_sql = text("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'ai_mentor'
            AND column_name IN ('default_rag_settings', 'default_rag_corpus')
        """)
        result = await conn.execute(check_sql)
        existing_columns = [row[0] for row in result.fetchall()]

        # Add default_rag_settings column if not exists
        if 'default_rag_settings' not in existing_columns:
            print("Adding default_rag_settings column...")
            await conn.execute(text("""
                ALTER TABLE ai_mentor
                ADD COLUMN default_rag_settings JSONB NOT NULL DEFAULT '{
                    "enabled": true,
                    "max_memories": 5,
                    "max_recent_messages": 10,
                    "time_decay_factor": 0.1,
                    "min_relevance_score": 0.0
                }'::jsonb
            """))
            print("Added default_rag_settings column")
        else:
            print("default_rag_settings column already exists")

        # Add default_rag_corpus column if not exists
        if 'default_rag_corpus' not in existing_columns:
            print("Adding default_rag_corpus column...")
            await conn.execute(text("""
                ALTER TABLE ai_mentor
                ADD COLUMN default_rag_corpus JSONB NOT NULL DEFAULT '[]'::jsonb
            """))
            print("Added default_rag_corpus column")
        else:
            print("default_rag_corpus column already exists")

        print("Migration 004 completed successfully!")


if __name__ == "__main__":
    asyncio.run(run_migration())

-- Migration: Update vector dimension from 1536 to 1024
-- Date: 2024-12-10
-- Description: 更新 target_memory 表的 embedding 列维度
--              从 1536 维 (OpenAI) 改为 1024 维 (豆包 Embedding Large)

-- 注意: 执行此迁移会清除现有的 embedding 数据
-- 如果需要保留数据，请先备份并在迁移后重新生成 embeddings

BEGIN;

-- 1. 删除现有的 embedding 列
ALTER TABLE target_memory DROP COLUMN IF EXISTS embedding;

-- 2. 重新创建 embedding 列 (1024 维)
ALTER TABLE target_memory ADD COLUMN embedding vector(1024);

-- 3. 创建向量索引 (使用 IVFFlat 索引，适合中等规模数据)
-- 注意: 如果数据量较大 (>100万)，考虑使用 HNSW 索引
DROP INDEX IF EXISTS idx_target_memory_embedding;
CREATE INDEX idx_target_memory_embedding ON target_memory
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- 4. 添加注释
COMMENT ON COLUMN target_memory.embedding IS '记忆内容的向量嵌入 (1024维, 豆包 Embedding Large)';

COMMIT;

-- 验证迁移
-- SELECT
--     column_name,
--     data_type,
--     character_maximum_length
-- FROM information_schema.columns
-- WHERE table_name = 'target_memory' AND column_name = 'embedding';

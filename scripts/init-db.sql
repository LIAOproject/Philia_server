-- Philia 数据库初始化脚本
-- 启用 pgvector 扩展和 UUID 生成

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 表 1: 对象档案 (Target Profile)
-- 存储跟踪的人物档案信息
CREATE TABLE IF NOT EXISTS target_profile (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    avatar_url TEXT,
    -- 当前关系状态: pursuing (追求中), dating (约会中), friend (朋友), complicated (复杂), ended (已结束)
    current_status VARCHAR(50) DEFAULT 'pursuing',

    -- 动态画像 (JSONB)
    -- 豆包擅长提取中式标签，如 "E人", "纯欲风", "国企工作"
    -- 结构示例: { "tags": ["E人", "爱旅游"], "mbti": "ENFP", "zodiac": "天蝎座", "age_range": "25-28" }
    profile_data JSONB DEFAULT '{}',

    -- 喜好 (JSONB)
    -- 结构示例: { "likes": ["猫", "咖啡", "日系穿搭"], "dislikes": ["抽烟", "熬夜"] }
    preferences JSONB DEFAULT '{ "likes": [], "dislikes": [] }',

    -- AI 生成的综合摘要
    ai_summary TEXT,

    -- 亲密度评分 (0-100)
    intimacy_score INTEGER DEFAULT 50 CHECK (intimacy_score >= 0 AND intimacy_score <= 100),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 表 2: 对象记忆 (Target Memory)
-- 存储每次交互的事件记录
CREATE TABLE IF NOT EXISTS target_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_id UUID REFERENCES target_profile(id) ON DELETE CASCADE,

    -- 事件发生时间 (从截图中提取或用户指定)
    happened_at TIMESTAMPTZ NOT NULL,

    -- 来源类型: wechat (微信), qq, tantan (探探), soul, xiaohongshu (小红书), photo (照片), manual (手动)
    source_type VARCHAR(20) NOT NULL,

    -- 原始内容文本 (对话记录或描述)
    content TEXT,

    -- 原始图片存储路径
    image_url TEXT,

    -- 结构化事实 (AI 提取)
    -- 示例: { "sentiment": "阴阳怪气", "key_event": "争吵", "topics": ["工作", "约会"] }
    extracted_facts JSONB DEFAULT '{}',

    -- 情绪评分 (-10 到 10, 负数为负面)
    sentiment_score INTEGER DEFAULT 0 CHECK (sentiment_score >= -10 AND sentiment_score <= 10),

    -- 向量 Embedding (1536 维，用于语义搜索)
    -- 暂用全 0 占位，后续接入 Embedding 模型
    embedding vector(1536),

    -- 去重指纹 (基于内容的 MD5 哈希)
    content_hash VARCHAR(64),

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 表 3: 标签字典 (Tags) - 可选，用于标签标准化
CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    category VARCHAR(50), -- personality (性格), hobby (爱好), appearance (外貌), lifestyle (生活方式)
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 索引优化
CREATE INDEX IF NOT EXISTS idx_memory_target_id ON target_memory(target_id);
CREATE INDEX IF NOT EXISTS idx_memory_happened_at ON target_memory(happened_at DESC);
CREATE INDEX IF NOT EXISTS idx_memory_source_type ON target_memory(source_type);
CREATE INDEX IF NOT EXISTS idx_memory_content_hash ON target_memory(content_hash);
CREATE INDEX IF NOT EXISTS idx_profile_status ON target_profile(current_status);
CREATE INDEX IF NOT EXISTS idx_profile_updated_at ON target_profile(updated_at DESC);

-- GIN 索引用于 JSONB 查询
CREATE INDEX IF NOT EXISTS idx_profile_data ON target_profile USING GIN(profile_data);
CREATE INDEX IF NOT EXISTS idx_profile_preferences ON target_profile USING GIN(preferences);
CREATE INDEX IF NOT EXISTS idx_memory_extracted_facts ON target_memory USING GIN(extracted_facts);

-- 向量索引 (用于相似度搜索)
-- 使用 IVFFlat 索引，适合中等规模数据
-- 注意: 需要先插入一些数据后才能创建此索引
-- CREATE INDEX IF NOT EXISTS idx_memory_embedding ON target_memory USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 触发器: 自动更新 updated_at 字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_profile_updated_at
    BEFORE UPDATE ON target_profile
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 初始化示例数据 (可选，用于开发测试)
-- INSERT INTO target_profile (name, current_status, profile_data, preferences)
-- VALUES (
--     '测试对象',
--     'pursuing',
--     '{"tags": ["E人", "爱旅游", "养猫"], "mbti": "ENFP", "zodiac": "天蝎座"}',
--     '{"likes": ["咖啡", "电影"], "dislikes": ["抽烟"]}'
-- );

COMMENT ON TABLE target_profile IS '对象档案表 - 存储跟踪的人物信息';
COMMENT ON TABLE target_memory IS '对象记忆表 - 存储每次交互的事件记录';
COMMENT ON TABLE tags IS '标签字典表 - 用于标签标准化和统计';

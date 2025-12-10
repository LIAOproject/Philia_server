"""
Relation-OS 配置管理
从环境变量读取所有配置项
"""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """应用配置类"""

    # 应用基础配置
    APP_NAME: str = "Philia"
    APP_VERSION: str = "0.1.0"
    DEBUG: bool = False
    SECRET_KEY: str = "your-super-secret-key-change-in-production"

    # 数据库配置
    DATABASE_URL: str = "postgresql+asyncpg://relation_user:relation_secret_2024@localhost:5432/relation_os"

    # Redis 配置
    REDIS_URL: str = "redis://localhost:6379/0"

    # 火山引擎 API 配置
    # 访问凭证 (用于签名认证)
    VOLC_ACCESSKEY: Optional[str] = None
    VOLC_SECRETKEY: Optional[str] = None

    # 方舟 API Key (推荐使用，更简单)
    ARK_API_KEY: Optional[str] = None

    # 推理接入点 ID (火山引擎特有)
    # 在火山引擎控制台 -> 模型推理 -> 接入点管理 中获取
    ENDPOINT_ID: Optional[str] = None

    # Embedding 模型接入点 ID (豆包 Embedding Large)
    EMBEDDING_ENDPOINT_ID: str = "ep-20251208040132-848sr"

    # 模型配置
    # Doubao-Seed-1.6-vision (视觉理解模型)
    MODEL_NAME: str = "Doubao-Seed-1.6-vision"

    # 火山方舟 API 基础 URL
    ARK_BASE_URL: str = "https://ark.cn-beijing.volces.com/api/v3"

    # 文件上传配置
    UPLOAD_DIR: str = "/app/uploads"
    MAX_FILE_SIZE: int = 10 * 1024 * 1024  # 10MB
    ALLOWED_EXTENSIONS: set = {"png", "jpg", "jpeg", "gif", "webp"}

    # CORS 配置
    CORS_ORIGINS: list = [
        "http://localhost:3000",
        "http://127.0.0.1:3000",
        "http://14.103.211.140:3000",
        "http://demo.philia.chat",
    ]

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """获取配置单例"""
    return Settings()


# 导出配置实例
settings = get_settings()

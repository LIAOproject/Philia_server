"""
Philia FastAPI 主程序入口
人际关系管理系统 MVP
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from loguru import logger

from app.api import chat, memories, targets, upload
from app.core.config import settings
from app.core.database import AsyncSessionLocal, close_db, init_db
from app.services.seed_mentors import seed_mentors


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时
    logger.info(f"启动 {settings.APP_NAME} v{settings.APP_VERSION}")

    # 初始化数据库 (开发模式)
    if settings.DEBUG:
        try:
            await init_db()
            logger.info("数据库表已创建/验证")

            # 初始化默认导师数据
            async with AsyncSessionLocal() as db:
                created = await seed_mentors(db)
                if created > 0:
                    logger.info(f"已创建 {created} 个默认 AI 导师")
        except Exception as e:
            logger.error(f"数据库初始化失败: {e}")

    yield

    # 关闭时
    logger.info("正在关闭应用...")
    await close_db()


# 创建 FastAPI 应用
app = FastAPI(
    title=settings.APP_NAME,
    description="""
# Philia API

人际关系管理系统 MVP - 使用豆包 Vision 模型进行图片分析

## 核心功能

- **Targets (对象管理)**: 创建、查看、更新关系对象档案
- **Memories (记忆查询)**: 查询与对象相关的事件记录（记忆由系统自动创建）
- **Upload (图片上传)**: 上传图片并使用 AI 自动分析提取记忆

## AI 能力

- 识别微信/QQ/探探/Soul/小红书截图
- 提取人物特征标签 (E人、I人、MBTI、星座等)
- 分析对话情绪和潜台词
- 识别危险信号 (Red Flags) 和积极信号 (Green Flags)
    """,
    version=settings.APP_VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 全局异常处理
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """全局异常处理器"""
    logger.error(f"未处理的异常: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"detail": "服务器内部错误", "error": str(exc) if settings.DEBUG else None},
    )


# 挂载静态文件 (上传的图片)
try:
    app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")
except RuntimeError:
    # 目录不存在时跳过
    logger.warning(f"上传目录 {settings.UPLOAD_DIR} 不存在，将在首次上传时创建")

# 注册路由
app.include_router(targets.router, prefix="/api/v1")
app.include_router(memories.router, prefix="/api/v1")
app.include_router(upload.router, prefix="/api/v1")
app.include_router(chat.router, prefix="/api/v1")


# 健康检查接口
@app.get("/health", tags=["System"])
async def health_check():
    """健康检查"""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
    }


# 根路径
@app.get("/", tags=["System"])
async def root():
    """API 根路径"""
    return {
        "message": f"欢迎使用 {settings.APP_NAME}",
        "version": settings.APP_VERSION,
        "docs": "/docs",
        "api_prefix": "/api/v1",
    }


# API 配置信息 (仅开发模式)
@app.get("/api/config", tags=["System"])
async def get_config():
    """获取 API 配置信息 (仅开发模式)"""
    if not settings.DEBUG:
        return {"message": "仅在开发模式下可用"}

    return {
        "ai_configured": bool(settings.ARK_API_KEY and settings.ENDPOINT_ID),
        "endpoint_id": settings.ENDPOINT_ID[:8] + "..." if settings.ENDPOINT_ID else None,
        "model": settings.MODEL_NAME,
        "max_file_size_mb": settings.MAX_FILE_SIZE // 1024 // 1024,
        "allowed_extensions": list(settings.ALLOWED_EXTENSIONS),
    }

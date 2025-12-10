# CLAUDE_chinese.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指导。

## 项目概述

Philia 是一个 AI 驱动的关系管理系统，通过图像识别和对话分析来分析人际互动。它使用火山引擎（豆包）Vision 模型从聊天截图中提取信息。

## 架构

```
前端 (Next.js:3000) → 后端 (FastAPI:8000) → PostgreSQL (pgvector:5433) + Redis (6380)
                                ↓
                     火山引擎 / 豆包 Vision API
```

- **后端**: FastAPI + 异步 SQLAlchemy，pgvector 用于向量相似度搜索
- **前端**: Next.js 14 App Router + React Query + Zustand + Radix UI
- **数据库**: PostgreSQL 16 + pgvector 扩展（用于向量嵌入）
- **AI**: 火山引擎 SDK（兼容 OpenAI API）

## 常用命令

### Docker Compose（推荐）
```bash
cp .env.example .env          # 首次配置
docker-compose up -d          # 启动所有服务
docker-compose logs -f backend  # 查看后端日志
docker-compose down           # 停止服务
```

### 前端
```bash
cd frontend
npm install
npm run dev      # 开发服务器 (localhost:3000)
npm run build    # 生产构建
npm run lint     # ESLint 检查
```

### 后端
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### 数据库迁移
```bash
cd backend
alembic upgrade head      # 应用迁移
alembic downgrade -1      # 回滚一个迁移
```

## 关键目录

- `backend/app/api/` - FastAPI 路由处理器（targets, memories, upload, chat）
- `backend/app/services/` - 业务逻辑（chat_service, llm_service, embedding_service, 记忆去重/冲突处理）
- `backend/app/models/` - SQLAlchemy ORM 模型（含 pgvector 向量列）
- `frontend/src/app/` - Next.js App Router 页面
- `frontend/src/components/features/` - 功能组件（聊天、上传、档案卡片）
- `frontend/src/lib/api.ts` - 所有后端调用的 API 客户端

## API 结构

所有端点以 `/api/v1` 为前缀：
- `/targets` - 关系对象的增删改查
- `/memories` - 事件/互动记录
- `/upload/analyze` - 图片上传 + AI 分析
- `/chat/mentors` - AI 导师管理
- `/chat/chatbots` - 聊天会话管理（支持流式输出）

API 文档: http://localhost:8000/docs

## 环境变量

`.env` 文件必需配置：
```
ARK_API_KEY=your_ark_api_key          # 火山引擎 API 密钥
ENDPOINT_ID=ep-xxx                     # 视觉模型端点
EMBEDDING_ENDPOINT_ID=ep-xxx           # 嵌入模型端点
POSTGRES_USER=relation_user
POSTGRES_PASSWORD=relation_secret_2024
POSTGRES_DB=relation_os
```

## 关键模式

### 后端
- 所有数据库操作使用 async/await + SQLAlchemy 异步会话
- 服务通过依赖注入访问（`Depends(get_db)`）
- 记忆去重使用嵌入向量的余弦相似度阈值（0.92）
- RAG 检索结合向量相似度（0.8 权重）+ 时间衰减（0.2 权重）

### 前端
- 所有交互组件使用 `'use client'` 指令
- 服务端状态使用 TanStack React Query 管理
- 聊天使用 SSE 流式传输（`sendMessageStream` API）
- UI 组件采用 shadcn/ui 风格（Radix 原语 + Tailwind）

## 数据库

PostgreSQL + pgvector 扩展：
- `target_profile` - 关系对象档案（JSONB profile_data）
- `target_memory` - 事件记忆（含向量嵌入用于相似度搜索）
- `ai_mentor` - 可配置的 AI 导师人设
- `chatbot` - 聊天会话（关联对象和导师）
- `chat_message` - 对话历史

使用端口 5433 以避免与本地 PostgreSQL 冲突。

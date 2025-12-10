# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Philia is an AI-powered relationship management system that analyzes interpersonal interactions through image recognition and conversation analysis. It uses Volcanc Engine (豆包) Vision model to extract information from chat screenshots.

## Architecture

```
Frontend (Next.js:3000) → Backend (FastAPI:8000) → PostgreSQL (pgvector:5433) + Redis (6380)
                                    ↓
                         Volcanc Engine / 豆包 Vision API
```

- **Backend**: FastAPI with async SQLAlchemy, pgvector for vector similarity search
- **Frontend**: Next.js 14 App Router with React Query, Zustand, Radix UI
- **Database**: PostgreSQL 16 with pgvector extension for embeddings
- **AI**: Volcanc Engine SDK (OpenAI-compatible API)

## Commands

### Docker Compose (Recommended)
```bash
cp .env.example .env          # First time setup
docker-compose up -d          # Start all services
docker-compose logs -f backend  # View backend logs
docker-compose down           # Stop services
```

### Frontend
```bash
cd frontend
npm install
npm run dev      # Development server (localhost:3000)
npm run build    # Production build
npm run lint     # ESLint check
```

### Backend
```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

### Database Migrations
```bash
cd backend
alembic upgrade head      # Apply migrations
alembic downgrade -1      # Rollback one migration
```

## Key Directories

- `backend/app/api/` - FastAPI route handlers (targets, memories, upload, chat)
- `backend/app/services/` - Business logic (chat_service, llm_service, embedding_service, memory dedup/conflict)
- `backend/app/models/` - SQLAlchemy ORM models with pgvector columns
- `frontend/src/app/` - Next.js App Router pages
- `frontend/src/components/features/` - Feature components (chat, upload, profile cards)
- `frontend/src/lib/api.ts` - API client for all backend calls

## API Structure

All endpoints are prefixed with `/api/v1`:
- `/targets` - CRUD for relationship profiles
- `/memories` - Event/interaction records
- `/upload/analyze` - Image upload + AI analysis
- `/chat/mentors` - AI mentor management
- `/chat/chatbots` - Chat session management with streaming support

API docs: http://localhost:8000/docs

## Environment Variables

Required in `.env`:
```
ARK_API_KEY=your_ark_api_key          # Volcanc Engine API key
ENDPOINT_ID=ep-xxx                     # Vision model endpoint
EMBEDDING_ENDPOINT_ID=ep-xxx           # Embedding model endpoint
POSTGRES_USER=relation_user
POSTGRES_PASSWORD=relation_secret_2024
POSTGRES_DB=relation_os
```

## Key Patterns

### Backend
- All database operations use async/await with SQLAlchemy async sessions
- Services are accessed via dependency injection (`Depends(get_db)`)
- Memory deduplication uses cosine similarity threshold (0.92) on embeddings
- RAG retrieval combines vector similarity (0.8 weight) + time decay (0.2 weight)

### Frontend
- All interactive components use `'use client'` directive
- Server state managed with TanStack React Query
- Chat uses SSE streaming via `sendMessageStream` API
- UI components are shadcn/ui style (Radix primitives + Tailwind)

## Database

PostgreSQL with pgvector extension:
- `target_profile` - Relationship targets with JSONB profile_data
- `target_memory` - Events with vector embeddings for similarity search
- `ai_mentor` - Configurable AI mentor personas
- `chatbot` - Chat sessions linking targets to mentors
- `chat_message` - Conversation history

Port 5433 is used to avoid conflicts with local PostgreSQL installations.

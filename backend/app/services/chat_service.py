"""
Philia Chat Service
核心聊天服务：上下文组装、RAG 检索、LLM 调用、记忆回流

支持两种模式:
1. 传统模式: 直接 RAG + LLM 调用
2. LangGraph 模式: 自适应路由，根据意图决定是否 RAG
"""

import json
from datetime import datetime, timezone
from typing import AsyncGenerator, Optional
from uuid import UUID

from loguru import logger
from openai import AsyncOpenAI, OpenAI
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.chat import AIMentor, Chatbot, ChatMessage
from app.models.relationship import TargetMemory, TargetProfile
from app.schemas.chat import ChatContext, ChatMessageResponse, RetrievedMemory

# LangGraph 模块导入
from app.services.chat.graph import run_chat_graph, run_chat_graph_stream
from app.services.chat.state import (
    ChatMessage as LGChatMessage,
    MentorConfig,
    RAGConfig,
    TargetProfileSummary,
)
from app.services.embedding_service import get_embedding
from app.services.memory_dedup_service import check_duplicate_memory
from app.services.memory_conflict_service import handle_memory_conflict


class ChatService:
    """聊天服务类"""

    def __init__(self):
        self._client: Optional[OpenAI] = None
        self._async_client: Optional[AsyncOpenAI] = None

    def _get_client(self) -> OpenAI:
        """获取 OpenAI 兼容客户端（同步）"""
        if self._client is None:
            self._client = OpenAI(
                api_key=settings.ARK_API_KEY,
                base_url=settings.ARK_BASE_URL,
            )
        return self._client

    def _get_async_client(self) -> AsyncOpenAI:
        """获取 OpenAI 兼容客户端（异步，用于流式输出）"""
        if self._async_client is None:
            self._async_client = AsyncOpenAI(
                api_key=settings.ARK_API_KEY,
                base_url=settings.ARK_BASE_URL,
            )
        return self._async_client

    async def get_chat_context(
        self,
        db: AsyncSession,
        chatbot: Chatbot,
        user_message: str,
        max_memories: int = 5,
        max_recent_messages: int = 10,
    ) -> ChatContext:
        """
        组装聊天上下文

        Args:
            db: 数据库会话
            chatbot: Chatbot 实例
            user_message: 用户消息 (用于 RAG 检索)
            max_memories: 最大检索记忆数 (可被 chatbot.rag_settings 覆盖)
            max_recent_messages: 最大历史消息数 (可被 chatbot.rag_settings 覆盖)

        Returns:
            ChatContext: 组装好的上下文
        """
        # 从 chatbot 的 rag_settings 读取配置
        rag_settings = chatbot.rag_settings or {}
        rag_enabled = rag_settings.get("enabled", True)
        max_memories = rag_settings.get("max_memories", max_memories)
        max_recent_messages = rag_settings.get("max_recent_messages", max_recent_messages)
        time_decay_factor = rag_settings.get("time_decay_factor", 0.1)
        min_relevance_score = rag_settings.get("min_relevance_score", 0.0)

        # 1. 获取 Target 信息
        target_query = select(TargetProfile).where(TargetProfile.id == chatbot.target_id)
        target_result = await db.execute(target_query)
        target = target_result.scalar_one_or_none()

        if not target:
            raise ValueError(f"Target {chatbot.target_id} not found")

        # 2. 构建 profile_summary
        profile_summary = self._build_profile_summary(target)

        # 3. 构建 preferences
        preferences = self._build_preferences_summary(target)

        # 4. RAG 检索相关记忆 (如果启用)
        retrieved_memories = []
        if rag_enabled and max_memories > 0:
            retrieved_memories = await self._retrieve_memories(
                db=db,
                target_id=chatbot.target_id,
                query=user_message,
                limit=max_memories,
                time_decay_factor=time_decay_factor,
                min_relevance_score=min_relevance_score,
                custom_corpus=chatbot.rag_corpus or [],
            )

        # 5. 获取最近的聊天记录
        messages_query = (
            select(ChatMessage)
            .where(ChatMessage.chatbot_id == chatbot.id)
            .order_by(ChatMessage.created_at.desc())
            .limit(max_recent_messages)
        )
        messages_result = await db.execute(messages_query)
        messages = list(reversed(messages_result.scalars().all()))

        recent_messages = [
            ChatMessageResponse(
                id=msg.id,
                chatbot_id=msg.chatbot_id,
                role=msg.role,
                content=msg.content,
                created_at=msg.created_at,
            )
            for msg in messages
        ]

        return ChatContext(
            target_name=target.name,
            profile_summary=profile_summary,
            preferences=preferences,
            retrieved_memories=retrieved_memories,
            recent_messages=recent_messages,
        )

    def _build_profile_summary(self, target: TargetProfile) -> str:
        """构建 Target 画像摘要"""
        parts = []

        profile_data = target.profile_data or {}

        if profile_data.get("tags"):
            parts.append(f"标签: {', '.join(profile_data['tags'])}")

        if profile_data.get("mbti"):
            parts.append(f"MBTI: {profile_data['mbti']}")

        if profile_data.get("zodiac"):
            parts.append(f"星座: {profile_data['zodiac']}")

        if profile_data.get("age_range"):
            parts.append(f"年龄: {profile_data['age_range']}")

        if profile_data.get("occupation"):
            parts.append(f"职业: {profile_data['occupation']}")

        if profile_data.get("location"):
            parts.append(f"所在地: {profile_data['location']}")

        if profile_data.get("personality"):
            personality = profile_data["personality"]
            if isinstance(personality, dict):
                parts.append(f"性格特点: {', '.join(f'{k}:{v}' for k, v in personality.items())}")

        if target.ai_summary:
            parts.append(f"综合评价: {target.ai_summary}")

        if target.current_status:
            status_map = {
                "pursuing": "追求中",
                "dating": "约会中",
                "friend": "朋友",
                "complicated": "关系复杂",
                "ended": "已结束",
            }
            parts.append(f"当前状态: {status_map.get(target.current_status, target.current_status)}")

        return "\n".join(parts) if parts else "暂无详细信息"

    def _build_preferences_summary(self, target: TargetProfile) -> str:
        """构建喜好摘要"""
        preferences = target.preferences or {}
        parts = []

        likes = preferences.get("likes", [])
        dislikes = preferences.get("dislikes", [])

        if likes:
            parts.append(f"喜欢: {', '.join(likes)}")

        if dislikes:
            parts.append(f"不喜欢: {', '.join(dislikes)}")

        return "\n".join(parts) if parts else "暂无喜好信息"

    async def _retrieve_memories(
        self,
        db: AsyncSession,
        target_id: UUID,
        query: str,
        limit: int = 5,
        time_decay_factor: float = 0.1,
        min_relevance_score: float = 0.0,
        custom_corpus: list = None,
    ) -> list[RetrievedMemory]:
        """
        RAG 检索相关记忆

        目前使用简单的关键词匹配，后续可扩展为向量检索

        Args:
            db: 数据库会话
            target_id: Target ID
            query: 查询文本
            limit: 最大返回数量
            time_decay_factor: 时间衰减因子 (0-1, 越高越偏好新记忆)
            min_relevance_score: 最小相关性分数过滤
            custom_corpus: 自定义语料库
        """
        if custom_corpus is None:
            custom_corpus = []

        # TODO: 实现向量检索 (需要先生成 embeddings)
        # 目前使用简单的文本搜索

        # 使用 PostgreSQL 全文搜索
        # 先尝试简单的 ILIKE 匹配
        # 只查询 active 状态的记忆
        memories_query = (
            select(TargetMemory)
            .where(TargetMemory.target_id == target_id)
            .where(TargetMemory.content.isnot(None))
            .where(TargetMemory.status == "active")
            .order_by(TargetMemory.happened_at.desc())
            .limit(limit * 3)  # 多取一些用于过滤
        )

        result = await db.execute(memories_query)
        memories = result.scalars().all()

        # 简单的关键词匹配评分
        query_keywords = set(query.lower().split())
        scored_memories = []

        for memory in memories:
            if not memory.content:
                continue

            content_lower = memory.content.lower()
            # 计算关键词命中数
            hits = sum(1 for kw in query_keywords if kw in content_lower)
            # 时间衰减因子 (越新的记忆权重越高)
            days_ago = (datetime.now(timezone.utc) - memory.happened_at.replace(tzinfo=timezone.utc)).days
            time_factor = 1.0 / (1.0 + days_ago * time_decay_factor)

            score = hits * time_factor if hits > 0 else time_factor * 0.1

            # 过滤低于最小分数的结果
            if score >= min_relevance_score:
                scored_memories.append((memory, score))

        # 添加自定义语料作为伪记忆
        for corpus_item in custom_corpus:
            content = corpus_item.get("content", "")
            if not content:
                continue

            content_lower = content.lower()
            hits = sum(1 for kw in query_keywords if kw in content_lower)
            score = hits * 0.5 if hits > 0 else 0.05  # 自定义语料分数稍低

            if score >= min_relevance_score:
                # 创建伪记忆对象
                scored_memories.append((
                    type("FakeMemory", (), {
                        "id": None,
                        "content": content,
                        "happened_at": datetime.now(timezone.utc),
                        "source_type": "corpus",
                        "sentiment_score": 0,
                    })(),
                    score,
                ))

        # 按评分排序，取 top N
        scored_memories.sort(key=lambda x: x[1], reverse=True)
        top_memories = scored_memories[:limit]

        return [
            RetrievedMemory(
                id=mem.id if mem.id else UUID("00000000-0000-0000-0000-000000000000"),
                content=mem.content or "",
                happened_at=mem.happened_at,
                source_type=mem.source_type,
                sentiment_score=mem.sentiment_score,
                relevance_score=score,
            )
            for mem, score in top_memories
        ]

    def build_system_prompt(
        self,
        mentor: AIMentor,
        context: ChatContext,
        custom_prompt: str = None,
    ) -> str:
        """
        构建最终的 System Prompt

        Args:
            mentor: AI 导师
            context: 聊天上下文
            custom_prompt: 自定义系统提示词 (覆盖 mentor 模板)

        Returns:
            完整的 system prompt
        """
        # 构建记忆上下文
        memory_context = ""
        if context.retrieved_memories:
            memory_parts = []
            for mem in context.retrieved_memories:
                memory_parts.append(
                    f"- [{mem.happened_at.strftime('%Y-%m-%d')}] {mem.content} "
                    f"(情绪: {mem.sentiment_score})"
                )
            memory_context = "\n".join(memory_parts)
        else:
            memory_context = "暂无相关历史记录"

        # 使用自定义 prompt 或 mentor 模板
        template = custom_prompt or mentor.system_prompt_template

        # 替换模板占位符
        try:
            system_prompt = template.format(
                target_name=context.target_name,
                profile_summary=context.profile_summary,
                preferences=context.preferences,
                context=memory_context,
            )
        except KeyError as e:
            logger.warning(f"System prompt template error: {e}")
            # 降级使用 mentor 原始模板
            system_prompt = mentor.system_prompt_template.format(
                target_name=context.target_name,
                profile_summary=context.profile_summary,
                preferences=context.preferences,
                context=memory_context,
            )

        return system_prompt

    def build_messages(
        self,
        system_prompt: str,
        context: ChatContext,
        user_message: str,
    ) -> list[dict]:
        """
        构建发送给 LLM 的消息列表

        Args:
            system_prompt: 系统提示词
            context: 聊天上下文
            user_message: 用户消息

        Returns:
            消息列表
        """
        messages = [{"role": "system", "content": system_prompt}]

        # 添加历史消息
        for msg in context.recent_messages:
            messages.append({"role": msg.role, "content": msg.content})

        # 添加当前用户消息
        messages.append({"role": "user", "content": user_message})

        return messages

    async def generate_response(
        self,
        messages: list[dict],
        stream: bool = False,
    ) -> str | AsyncGenerator[str, None]:
        """
        调用 LLM 生成回复

        Args:
            messages: 消息列表
            stream: 是否流式输出

        Returns:
            生成的回复内容
        """
        if stream:
            return self._stream_response(messages)
        else:
            client = self._get_client()
            response = client.chat.completions.create(
                model=settings.ENDPOINT_ID,
                messages=messages,
                max_tokens=2048,
                temperature=0.7,
            )
            return response.choices[0].message.content or ""

    async def _stream_response(
        self,
        messages: list[dict],
    ) -> AsyncGenerator[str, None]:
        """流式生成回复（使用异步客户端）"""
        client = self._get_async_client()
        response = await client.chat.completions.create(
            model=settings.ENDPOINT_ID,
            messages=messages,
            max_tokens=2048,
            temperature=0.7,
            stream=True,
        )

        async for chunk in response:
            if chunk.choices and chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    async def analyze_for_new_facts(
        self,
        db: AsyncSession,
        target_id: UUID,
        user_message: str,
        assistant_response: str,
    ) -> bool:
        """
        分析对话内容，提取新事实并创建记忆

        Args:
            db: 数据库会话
            target_id: Target ID
            user_message: 用户消息
            assistant_response: AI 回复

        Returns:
            是否创建了新记忆
        """
        # 构建分析 prompt
        analysis_prompt = f"""分析以下对话内容，判断用户是否透露了关于目标对象的新信息。

用户消息: {user_message}

如果用户消息中包含关于目标对象的新事实（如：新的事件、行为、态度变化、重要信息等），请提取并以 JSON 格式返回：

{{
    "has_new_fact": true/false,
    "content_summary": "事实摘要",
    "sentiment": "情绪类型 (积极/中性/消极)",
    "sentiment_score": -10到10的整数,
    "key_event": "关键事件或null",
    "topics": ["话题列表"]
}}

如果没有新信息，返回:
{{"has_new_fact": false}}

只返回 JSON，不要其他内容。
"""

        try:
            client = self._get_client()
            response = client.chat.completions.create(
                model=settings.ENDPOINT_ID,
                messages=[{"role": "user", "content": analysis_prompt}],
                max_tokens=500,
                temperature=0.3,
                response_format={"type": "json_object"},
            )

            result = json.loads(response.choices[0].message.content or "{}")

            if result.get("has_new_fact"):
                content_summary = result.get("content_summary", user_message)

                # 生成记忆内容的向量嵌入
                memory_embedding = get_embedding(content_summary)

                # 去重检查：检查是否已存在高度相似的记忆
                is_duplicate, existing_id, similarity = await check_duplicate_memory(
                    db=db,
                    target_id=target_id,
                    content=content_summary,
                    embedding=memory_embedding,
                )

                if is_duplicate:
                    logger.info(
                        f"跳过重复记忆 (相似度={similarity:.4f}): '{content_summary[:50]}...' "
                        f"已存在记忆 {existing_id}"
                    )
                    return False

                # 冲突检测：检查是否与已有记忆冲突，如果是则标记旧记忆为 outdated
                conflict_info = await handle_memory_conflict(
                    db=db,
                    target_id=target_id,
                    new_content=content_summary,
                    embedding=memory_embedding,
                )

                # 构建 extracted_facts
                extracted_facts = {
                    "sentiment": result.get("sentiment"),
                    "key_event": result.get("key_event"),
                    "topics": result.get("topics", []),
                    "source": "chat_analysis",
                }

                # 如果存在冲突，记录被替代的记忆ID
                if conflict_info:
                    extracted_facts["replaced_memory_id"] = conflict_info["replaced_memory_id"]
                    logger.info(
                        f"新记忆替代了旧记忆: {conflict_info['replaced_memory_id']}"
                    )

                # 创建新记忆 (带向量)
                new_memory = TargetMemory(
                    target_id=target_id,
                    happened_at=datetime.now(timezone.utc),
                    source_type="chat",  # 来源类型: 聊天
                    content=content_summary,
                    extracted_facts=extracted_facts,
                    sentiment_score=result.get("sentiment_score", 0),
                    embedding=memory_embedding,
                )
                db.add(new_memory)
                await db.commit()

                logger.info(f"从聊天中创建新记忆 (带向量): {content_summary}")
                return True

        except Exception as e:
            logger.error(f"分析对话失败: {e}")

        return False

    # ========================
    # LangGraph 自适应模式
    # ========================

    async def generate_response_adaptive(
        self,
        db: AsyncSession,
        chatbot: Chatbot,
        mentor: AIMentor,
        user_message: str,
    ) -> tuple[str, int]:
        """
        使用 LangGraph 自适应模式生成回复

        会自动判断用户意图，决定是否进行 RAG 检索

        Args:
            db: 数据库会话
            chatbot: Chatbot 实例
            mentor: AIMentor 实例
            user_message: 用户消息

        Returns:
            (生成的回复, 检索到的记忆数量)
        """
        # 获取 Target
        target_query = select(TargetProfile).where(TargetProfile.id == chatbot.target_id)
        target_result = await db.execute(target_query)
        target = target_result.scalar_one_or_none()

        if not target:
            raise ValueError(f"Target {chatbot.target_id} not found")

        # 构建 TargetProfileSummary
        target_profile = TargetProfileSummary(
            id=target.id,
            name=target.name,
            current_status=target.current_status,
            profile_summary=self._build_profile_summary(target),
            preferences=self._build_preferences_summary(target),
            ai_summary=target.ai_summary,
        )

        # 构建 MentorConfig
        mentor_config = MentorConfig(
            id=mentor.id,
            name=mentor.name,
            style_tag=mentor.style_tag,
            system_prompt_template=mentor.system_prompt_template,
        )

        # 构建 RAGConfig
        rag_settings = chatbot.rag_settings or {}
        rag_config = RAGConfig(
            enabled=rag_settings.get("enabled", True),
            max_memories=rag_settings.get("max_memories", 5),
            max_recent_messages=rag_settings.get("max_recent_messages", 10),
            time_decay_factor=rag_settings.get("time_decay_factor", 0.1),
            min_relevance_score=rag_settings.get("min_relevance_score", 0.0),
        )

        # 获取最近消息
        messages_query = (
            select(ChatMessage)
            .where(ChatMessage.chatbot_id == chatbot.id)
            .order_by(ChatMessage.created_at.desc())
            .limit(rag_config.max_recent_messages)
        )
        messages_result = await db.execute(messages_query)
        messages = list(reversed(messages_result.scalars().all()))

        recent_messages = [
            LGChatMessage(role=msg.role, content=msg.content)
            for msg in messages
        ]

        # 运行 LangGraph 工作流
        generation, retrieved_memories = await run_chat_graph(
            db=db,
            chatbot_id=chatbot.id,
            target_id=chatbot.target_id,
            target_profile=target_profile,
            mentor_config=mentor_config,
            rag_config=rag_config,
            rag_corpus=chatbot.rag_corpus or [],
            user_message=user_message,
            recent_messages=recent_messages,
        )

        return generation, len(retrieved_memories)

    async def generate_response_adaptive_stream(
        self,
        db: AsyncSession,
        chatbot: Chatbot,
        mentor: AIMentor,
        user_message: str,
    ) -> AsyncGenerator[str, None]:
        """
        使用 LangGraph 自适应模式流式生成回复

        Args:
            db: 数据库会话
            chatbot: Chatbot 实例
            mentor: AIMentor 实例
            user_message: 用户消息

        Yields:
            生成的文本片段
        """
        # 获取 Target
        target_query = select(TargetProfile).where(TargetProfile.id == chatbot.target_id)
        target_result = await db.execute(target_query)
        target = target_result.scalar_one_or_none()

        if not target:
            raise ValueError(f"Target {chatbot.target_id} not found")

        # 构建 TargetProfileSummary
        target_profile = TargetProfileSummary(
            id=target.id,
            name=target.name,
            current_status=target.current_status,
            profile_summary=self._build_profile_summary(target),
            preferences=self._build_preferences_summary(target),
            ai_summary=target.ai_summary,
        )

        # 构建 MentorConfig
        mentor_config = MentorConfig(
            id=mentor.id,
            name=mentor.name,
            style_tag=mentor.style_tag,
            system_prompt_template=mentor.system_prompt_template,
        )

        # 构建 RAGConfig
        rag_settings = chatbot.rag_settings or {}
        rag_config = RAGConfig(
            enabled=rag_settings.get("enabled", True),
            max_memories=rag_settings.get("max_memories", 5),
            max_recent_messages=rag_settings.get("max_recent_messages", 10),
            time_decay_factor=rag_settings.get("time_decay_factor", 0.1),
            min_relevance_score=rag_settings.get("min_relevance_score", 0.0),
        )

        # 获取最近消息
        messages_query = (
            select(ChatMessage)
            .where(ChatMessage.chatbot_id == chatbot.id)
            .order_by(ChatMessage.created_at.desc())
            .limit(rag_config.max_recent_messages)
        )
        messages_result = await db.execute(messages_query)
        messages = list(reversed(messages_result.scalars().all()))

        recent_messages = [
            LGChatMessage(role=msg.role, content=msg.content)
            for msg in messages
        ]

        # 运行 LangGraph 流式工作流
        async for chunk in run_chat_graph_stream(
            db=db,
            chatbot_id=chatbot.id,
            target_id=chatbot.target_id,
            target_profile=target_profile,
            mentor_config=mentor_config,
            rag_config=rag_config,
            rag_corpus=chatbot.rag_corpus or [],
            user_message=user_message,
            recent_messages=recent_messages,
        ):
            yield chunk


# 全局服务实例
_chat_service: Optional[ChatService] = None


def get_chat_service() -> ChatService:
    """获取聊天服务单例"""
    global _chat_service
    if _chat_service is None:
        _chat_service = ChatService()
    return _chat_service

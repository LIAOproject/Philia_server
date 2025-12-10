"""
Philia Chat - LangGraph 节点实现

实现对话工作流中的各个处理节点:
1. route_question: 意图分类器 - 判断用户意图
2. retrieve_memory: RAG 检索 - 从 Postgres 检索相关记忆
3. generate_mentor_response: 生成导师回复
4. grade_response: 评估回复质量 (可选)
5. extract_facts: 提取新事实创建记忆
"""

import json
from datetime import datetime, timezone
from typing import Literal
from uuid import UUID

from loguru import logger
from openai import OpenAI
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.models.relationship import TargetMemory
from app.services.chat.state import AgentState, ChatMessage, RetrievedMemory
from app.services.embedding_service import get_embedding
from app.services.memory_dedup_service import check_duplicate_memory
from app.services.memory_conflict_service import handle_memory_conflict


# ========================
# LLM 客户端
# ========================


def _get_llm_client() -> OpenAI:
    """获取 OpenAI 兼容客户端 (火山引擎)"""
    return OpenAI(
        api_key=settings.ARK_API_KEY,
        base_url=settings.ARK_BASE_URL,
    )


# ========================
# 路由数据模型
# ========================


class RouteDecision(BaseModel):
    """路由决策模型"""

    route: Literal["mentor_chat", "memory_rag"] = Field(
        ...,
        description="路由决策: mentor_chat (纯聊天) 或 memory_rag (需要检索记忆)",
    )
    reasoning: str = Field(..., description="路由理由")


# ========================
# 节点实现
# ========================


def route_question(state: AgentState) -> AgentState:
    """
    意图分类器节点

    判断用户是:
    - "闲聊/求安慰" -> mentor_chat (不需要 RAG)
    - "问过去的事/需要具体信息" -> memory_rag (需要 RAG 检索)

    Args:
        state: 当前状态

    Returns:
        更新后的状态 (添加 route_decision)
    """
    logger.info("---ROUTE QUESTION---")

    user_message = state["user_message"]
    target_name = state["target_profile"].name

    # 构建路由 prompt
    route_prompt = f"""你是一个意图分类器，判断用户的消息应该走哪条处理分支。

用户正在咨询关于 "{target_name}" 的情感问题。

## 分支说明

1. **mentor_chat** (纯情感咨询):
   - 用户在倾诉、求安慰、问建议
   - 不需要查询具体历史记录
   - 例如: "我好难过"、"我该怎么办"、"她是不是不喜欢我了"

2. **memory_rag** (需要检索记忆):
   - 用户问具体的历史事件或信息
   - 需要查询之前的聊天记录或事件
   - 例如: "她上次说了什么"、"我们是什么时候认识的"、"她的生日是几号"

## 用户消息
{user_message}

请判断应该走哪条分支，返回 JSON 格式:
{{"route": "mentor_chat 或 memory_rag", "reasoning": "判断理由"}}

只返回 JSON，不要其他内容。
"""

    try:
        client = _get_llm_client()
        response = client.chat.completions.create(
            model=settings.ENDPOINT_ID,
            messages=[{"role": "user", "content": route_prompt}],
            max_tokens=200,
            temperature=0.1,
            response_format={"type": "json_object"},
        )

        result = json.loads(response.choices[0].message.content or "{}")
        route = result.get("route", "mentor_chat")
        reasoning = result.get("reasoning", "")

        # 验证路由值
        if route not in ["mentor_chat", "memory_rag"]:
            route = "mentor_chat"

        logger.info(f"---ROUTE DECISION: {route}--- ({reasoning})")

        return {**state, "route_decision": route}

    except Exception as e:
        logger.error(f"路由决策失败: {e}")
        # 默认走 mentor_chat
        return {**state, "route_decision": "mentor_chat"}


async def retrieve_memory(state: AgentState, db: AsyncSession) -> AgentState:
    """
    RAG 检索节点 - 向量相似度检索

    使用 pgvector 从 Postgres 的 target_memory 表检索语义相关的记忆

    Args:
        state: 当前状态
        db: 数据库会话

    Returns:
        更新后的状态 (添加 retrieved_memories)
    """
    logger.info("---RETRIEVE MEMORY (Vector Search)---")

    rag_config = state["rag_config"]
    target_id = state["target_id"]
    user_message = state["user_message"]
    custom_corpus = state.get("rag_corpus", [])

    if not rag_config.enabled:
        logger.info("RAG 已禁用，跳过检索")
        return {**state, "retrieved_memories": []}

    try:
        # 1. 生成查询向量
        query_embedding = get_embedding(user_message)
        logger.debug(f"Generated query embedding ({len(query_embedding)} dims)")

        # 2. 使用 pgvector 进行向量相似度检索
        # 使用余弦距离 (<=>)，值越小越相似
        from sqlalchemy import text

        # 构建向量检索 SQL
        # 同时考虑向量相似度和时间衰减
        # 只查询 active 状态的记忆
        # 将 embedding 转换为字符串格式以避免 SQLAlchemy 参数解析问题
        query_embedding_str = "[" + ",".join(str(v) for v in query_embedding) + "]"
        vector_search_sql = text("""
            SELECT
                id, content, happened_at, source_type, sentiment_score,
                1 - (embedding <=> CAST(:query_embedding AS vector)) as similarity,
                EXTRACT(EPOCH FROM (NOW() - happened_at)) / 86400.0 as days_ago
            FROM target_memory
            WHERE target_id = :target_id
                AND content IS NOT NULL
                AND embedding IS NOT NULL
                AND status = 'active'
            ORDER BY embedding <=> CAST(:query_embedding AS vector)
            LIMIT :limit
        """)

        result = await db.execute(
            vector_search_sql,
            {
                "target_id": str(target_id),
                "query_embedding": query_embedding_str,
                "limit": rag_config.max_memories * 2,
            },
        )
        rows = result.fetchall()

        scored_memories: list[tuple[dict, float]] = []

        for row in rows:
            similarity = row.similarity or 0.0
            days_ago = row.days_ago or 0.0

            # 先检查向量相似度门槛
            if similarity < rag_config.min_similarity:
                continue

            # 结合相似度和时间衰减计算最终分数
            time_factor = 1.0 / (1.0 + days_ago * rag_config.time_decay_factor)
            final_score = similarity * 0.8 + time_factor * 0.2

            if final_score >= rag_config.min_relevance_score:
                scored_memories.append(
                    (
                        {
                            "id": row.id,
                            "content": row.content,
                            "happened_at": row.happened_at,
                            "source_type": row.source_type,
                            "sentiment_score": row.sentiment_score,
                        },
                        final_score,
                    )
                )

        # 3. 处理自定义语料 (使用关键词匹配作为回退)
        if custom_corpus:
            query_keywords = set(user_message.lower().split())
            for corpus_item in custom_corpus:
                content = corpus_item.get("content", "")
                if not content:
                    continue

                content_lower = content.lower()
                hits = sum(1 for kw in query_keywords if kw in content_lower)
                score = hits * 0.3 if hits > 0 else 0.05

                if score >= rag_config.min_relevance_score:
                    scored_memories.append(
                        (
                            {
                                "id": None,
                                "content": content,
                                "happened_at": datetime.now(timezone.utc),
                                "source_type": "corpus",
                                "sentiment_score": 0,
                            },
                            score,
                        )
                    )

        # 4. 排序并取 top N
        scored_memories.sort(key=lambda x: x[1], reverse=True)
        top_memories = scored_memories[: rag_config.max_memories]

        retrieved = [
            RetrievedMemory(
                id=mem["id"],
                content=mem["content"] or "",
                happened_at=mem["happened_at"],
                source_type=mem["source_type"],
                sentiment_score=mem["sentiment_score"],
                relevance_score=score,
            )
            for mem, score in top_memories
        ]

        logger.info(f"---RETRIEVED {len(retrieved)} MEMORIES (Vector Search)---")

        return {**state, "retrieved_memories": retrieved}

    except Exception as e:
        logger.error(f"向量检索失败: {e}")
        # 回退到简单关键词匹配
        return await _retrieve_memory_fallback(state, db)


async def _retrieve_memory_fallback(
    state: AgentState, db: AsyncSession
) -> AgentState:
    """
    关键词匹配回退方案

    当向量检索失败时 (如记忆没有 embedding)，使用关键词匹配
    """
    logger.warning("---FALLBACK TO KEYWORD SEARCH---")

    rag_config = state["rag_config"]
    target_id = state["target_id"]
    user_message = state["user_message"]
    custom_corpus = state.get("rag_corpus", [])

    try:
        memories_query = (
            select(TargetMemory)
            .where(TargetMemory.target_id == target_id)
            .where(TargetMemory.content.isnot(None))
            .where(TargetMemory.status == "active")  # 只查询有效记忆
            .order_by(TargetMemory.happened_at.desc())
            .limit(rag_config.max_memories * 3)
        )

        result = await db.execute(memories_query)
        memories = result.scalars().all()

        query_keywords = set(user_message.lower().split())
        scored_memories: list[tuple[dict, float]] = []

        for memory in memories:
            if not memory.content:
                continue

            content_lower = memory.content.lower()
            hits = sum(1 for kw in query_keywords if kw in content_lower)
            days_ago = (
                datetime.now(timezone.utc)
                - memory.happened_at.replace(tzinfo=timezone.utc)
            ).days
            time_factor = 1.0 / (1.0 + days_ago * rag_config.time_decay_factor)
            score = hits * time_factor if hits > 0 else time_factor * 0.1

            if score >= rag_config.min_relevance_score:
                scored_memories.append(
                    (
                        {
                            "id": memory.id,
                            "content": memory.content,
                            "happened_at": memory.happened_at,
                            "source_type": memory.source_type,
                            "sentiment_score": memory.sentiment_score,
                        },
                        score,
                    )
                )

        # 自定义语料
        for corpus_item in custom_corpus:
            content = corpus_item.get("content", "")
            if not content:
                continue
            content_lower = content.lower()
            hits = sum(1 for kw in query_keywords if kw in content_lower)
            score = hits * 0.3 if hits > 0 else 0.05
            if score >= rag_config.min_relevance_score:
                scored_memories.append(
                    (
                        {
                            "id": None,
                            "content": content,
                            "happened_at": datetime.now(timezone.utc),
                            "source_type": "corpus",
                            "sentiment_score": 0,
                        },
                        score,
                    )
                )

        scored_memories.sort(key=lambda x: x[1], reverse=True)
        top_memories = scored_memories[: rag_config.max_memories]

        retrieved = [
            RetrievedMemory(
                id=mem["id"],
                content=mem["content"] or "",
                happened_at=mem["happened_at"],
                source_type=mem["source_type"],
                sentiment_score=mem["sentiment_score"],
                relevance_score=score,
            )
            for mem, score in top_memories
        ]

        logger.info(f"---RETRIEVED {len(retrieved)} MEMORIES (Keyword Fallback)---")
        return {**state, "retrieved_memories": retrieved}

    except Exception as e:
        logger.error(f"关键词回退也失败: {e}")
        return {**state, "retrieved_memories": []}


def generate_mentor_response(state: AgentState) -> AgentState:
    """
    生成导师回复节点

    根据状态中的上下文，调用 LLM 生成情感导师回复

    Args:
        state: 当前状态

    Returns:
        更新后的状态 (添加 generation)
    """
    logger.info("---GENERATE MENTOR RESPONSE---")

    mentor_config = state["mentor_config"]
    target_profile = state["target_profile"]
    user_message = state["user_message"]
    recent_messages = state.get("recent_messages", [])
    retrieved_memories = state.get("retrieved_memories", [])

    # 构建记忆上下文
    memory_context = ""
    if retrieved_memories:
        memory_parts = []
        for mem in retrieved_memories:
            memory_parts.append(
                f"- [{mem.happened_at.strftime('%Y-%m-%d')}] {mem.content} "
                f"(情绪: {mem.sentiment_score})"
            )
        memory_context = "\n".join(memory_parts)
    else:
        memory_context = "暂无相关历史记录"

    # 构建 system prompt
    try:
        system_prompt = mentor_config.system_prompt_template.format(
            target_name=target_profile.name,
            profile_summary=target_profile.profile_summary,
            preferences=target_profile.preferences,
            context=memory_context,
        )
    except KeyError as e:
        logger.warning(f"System prompt 模板变量缺失: {e}")
        system_prompt = mentor_config.system_prompt_template

    # 构建消息列表
    messages = [{"role": "system", "content": system_prompt}]

    # 添加历史消息
    for msg in recent_messages:
        messages.append({"role": msg.role, "content": msg.content})

    # 添加当前用户消息
    messages.append({"role": "user", "content": user_message})

    try:
        client = _get_llm_client()
        response = client.chat.completions.create(
            model=settings.ENDPOINT_ID,
            messages=messages,
            max_tokens=2048,
            temperature=0.7,
        )

        generation = response.choices[0].message.content or ""
        logger.info(f"---GENERATED RESPONSE ({len(generation)} chars)---")

        # 判断是否需要提取事实 (简单启发式)
        needs_fact_extraction = any(
            keyword in user_message
            for keyword in ["她说", "他说", "发生了", "告诉我", "今天", "昨天", "刚才"]
        )

        return {
            **state,
            "generation": generation,
            "needs_fact_extraction": needs_fact_extraction,
        }

    except Exception as e:
        logger.error(f"生成回复失败: {e}")
        return {
            **state,
            "generation": "抱歉，我现在无法回复。请稍后再试。",
            "needs_fact_extraction": False,
            "error": str(e),
        }


async def extract_facts(state: AgentState, db: AsyncSession) -> AgentState:
    """
    事实提取节点

    分析对话内容，提取新事实并创建记忆

    Args:
        state: 当前状态
        db: 数据库会话

    Returns:
        更新后的状态
    """
    if not state.get("needs_fact_extraction", False):
        return state

    logger.info("---EXTRACT FACTS---")

    user_message = state["user_message"]
    target_id = state["target_id"]

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
        client = _get_llm_client()
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
            logger.debug(f"Generated embedding for new memory ({len(memory_embedding)} dims)")

            # 去重检查：检查是否已存在高度相似的记忆
            is_duplicate, existing_id, similarity = await check_duplicate_memory(
                db=db,
                target_id=target_id,
                content=content_summary,
                embedding=memory_embedding,
            )

            if is_duplicate:
                logger.info(
                    f"---SKIP DUPLICATE MEMORY (similarity={similarity:.4f}): "
                    f"'{content_summary[:50]}...' matches {existing_id}---"
                )
                return state

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
                    f"---NEW MEMORY REPLACES OLD: {conflict_info['replaced_memory_id']}---"
                )

            # 创建新记忆 (带向量)
            new_memory = TargetMemory(
                target_id=target_id,
                happened_at=datetime.now(timezone.utc),
                source_type="chat",
                content=content_summary,
                extracted_facts=extracted_facts,
                sentiment_score=result.get("sentiment_score", 0),
                embedding=memory_embedding,
            )
            db.add(new_memory)
            await db.commit()

            logger.info(f"---CREATED NEW MEMORY WITH EMBEDDING: {content_summary}---")

    except Exception as e:
        logger.error(f"事实提取失败: {e}")

    return state


# ========================
# 条件边 (Conditional Edges)
# ========================


def should_retrieve(state: AgentState) -> str:
    """
    决定是否需要 RAG 检索

    Returns:
        "retrieve" 或 "generate"
    """
    route = state.get("route_decision", "mentor_chat")

    if route == "memory_rag":
        return "retrieve"
    else:
        return "generate"

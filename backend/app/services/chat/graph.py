"""
Philia Chat - LangGraph 工作流定义

组装 StateGraph，实现自适应情感导师对话流程:

         START
           │
           ▼
    ┌─────────────┐
    │route_question│
    └─────────────┘
           │
           ▼
    ┌─────────────────┐
    │should_retrieve? │ (条件边)
    └─────────────────┘
         │         │
    memory_rag  mentor_chat
         │         │
         ▼         │
    ┌─────────┐    │
    │retrieve │    │
    └─────────┘    │
         │         │
         └────┬────┘
              ▼
    ┌───────────────┐
    │generate_mentor│
    └───────────────┘
              │
              ▼
    ┌───────────────┐
    │extract_facts  │ (可选)
    └───────────────┘
              │
              ▼
            END
"""

from functools import partial
from typing import Optional
from uuid import UUID

from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from app.services.chat.nodes import (
    extract_facts,
    generate_mentor_response,
    retrieve_memory,
    route_question,
    should_retrieve,
)
from app.services.chat.state import (
    AgentState,
    ChatMessage,
    MentorConfig,
    RAGConfig,
    RetrievedMemory,
    TargetProfileSummary,
)

# LangGraph 是否可用
LANGGRAPH_AVAILABLE = False

try:
    from langgraph.graph import END, START, StateGraph

    LANGGRAPH_AVAILABLE = True
except ImportError:
    logger.warning(
        "langgraph 未安装，将使用简化版本。安装命令: pip install langgraph"
    )


def create_chat_graph():
    """
    创建聊天工作流图

    Returns:
        编译后的工作流 (如果 langgraph 可用) 或 None
    """
    if not LANGGRAPH_AVAILABLE:
        logger.warning("LangGraph 不可用，返回 None")
        return None

    # 创建状态图
    workflow = StateGraph(AgentState)

    # 添加节点
    workflow.add_node("route_question", route_question)
    workflow.add_node("generate_mentor", generate_mentor_response)

    # 注意: retrieve_memory 和 extract_facts 需要 db 参数
    # 这里我们只添加节点名，实际调用时会用 partial 注入 db
    # 由于 LangGraph 节点函数签名固定，我们需要用 wrapper

    # 构建图
    workflow.add_edge(START, "route_question")

    # 条件边: 根据路由决策决定是否检索
    workflow.add_conditional_edges(
        "route_question",
        should_retrieve,
        {
            "retrieve": "retrieve",  # 需要实际运行时注入
            "generate": "generate_mentor",
        },
    )

    # retrieve -> generate
    workflow.add_edge("retrieve", "generate_mentor")

    # generate -> END
    workflow.add_edge("generate_mentor", END)

    # 编译
    app = workflow.compile()

    return app


async def run_chat_graph(
    db: AsyncSession,
    chatbot_id: UUID,
    target_id: UUID,
    target_profile: TargetProfileSummary,
    mentor_config: MentorConfig,
    rag_config: RAGConfig,
    rag_corpus: list[dict],
    user_message: str,
    recent_messages: list[ChatMessage],
) -> tuple[str, list[RetrievedMemory]]:
    """
    运行聊天工作流 (简化版，不依赖 LangGraph)

    这是一个手动实现的工作流，按照以下步骤执行:
    1. 路由决策
    2. (可选) RAG 检索
    3. 生成回复
    4. (可选) 事实提取

    Args:
        db: 数据库会话
        chatbot_id: Chatbot ID
        target_id: Target ID
        target_profile: 对象档案
        mentor_config: 导师配置
        rag_config: RAG 配置
        rag_corpus: 自定义语料库
        user_message: 用户消息
        recent_messages: 最近消息历史

    Returns:
        (生成的回复, 检索到的记忆)
    """
    logger.info(f"---RUN CHAT GRAPH for Chatbot {chatbot_id}---")

    # 初始化状态
    state: AgentState = {
        "chatbot_id": chatbot_id,
        "target_id": target_id,
        "target_profile": target_profile,
        "mentor_config": mentor_config,
        "rag_config": rag_config,
        "rag_corpus": rag_corpus,
        "user_message": user_message,
        "recent_messages": recent_messages,
        "retrieved_memories": [],
        "route_decision": "mentor_chat",
        "generation": "",
        "needs_fact_extraction": False,
        "error": None,
    }

    # Step 1: 路由决策
    state = route_question(state)
    logger.info(f"Route decision: {state['route_decision']}")

    # Step 2: (可选) RAG 检索
    if state["route_decision"] == "memory_rag":
        state = await retrieve_memory(state, db)
        logger.info(f"Retrieved {len(state['retrieved_memories'])} memories")
    else:
        # 即使不走 RAG，也可以选择性地获取少量最近记忆作为背景
        # 这里我们暂时不这样做，保持简单
        pass

    # Step 3: 生成回复
    state = generate_mentor_response(state)

    # Step 4: (可选) 事实提取
    if state.get("needs_fact_extraction", False):
        state = await extract_facts(state, db)

    # 返回结果
    return state["generation"], state["retrieved_memories"]


async def run_chat_graph_stream(
    db: AsyncSession,
    chatbot_id: UUID,
    target_id: UUID,
    target_profile: TargetProfileSummary,
    mentor_config: MentorConfig,
    rag_config: RAGConfig,
    rag_corpus: list[dict],
    user_message: str,
    recent_messages: list[ChatMessage],
):
    """
    流式运行聊天工作流

    与 run_chat_graph 类似，但生成部分使用流式输出

    Yields:
        str: 生成的文本片段
    """
    from openai import AsyncOpenAI

    from app.core.config import settings

    logger.info(f"---RUN CHAT GRAPH (STREAM) for Chatbot {chatbot_id}---")

    # 初始化状态
    state: AgentState = {
        "chatbot_id": chatbot_id,
        "target_id": target_id,
        "target_profile": target_profile,
        "mentor_config": mentor_config,
        "rag_config": rag_config,
        "rag_corpus": rag_corpus,
        "user_message": user_message,
        "recent_messages": recent_messages,
        "retrieved_memories": [],
        "route_decision": "mentor_chat",
        "generation": "",
        "needs_fact_extraction": False,
        "error": None,
    }

    # Step 1: 路由决策
    state = route_question(state)

    # Step 2: (可选) RAG 检索
    if state["route_decision"] == "memory_rag":
        state = await retrieve_memory(state, db)

    # Step 3: 流式生成回复
    mentor_config = state["mentor_config"]
    target_profile = state["target_profile"]
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

    for msg in recent_messages:
        messages.append({"role": msg.role, "content": msg.content})

    messages.append({"role": "user", "content": user_message})

    # 流式调用 LLM（使用异步客户端）
    client = AsyncOpenAI(
        api_key=settings.ARK_API_KEY,
        base_url=settings.ARK_BASE_URL,
    )

    response = await client.chat.completions.create(
        model=settings.ENDPOINT_ID,
        messages=messages,
        max_tokens=2048,
        temperature=0.7,
        stream=True,
    )

    full_response = ""
    async for chunk in response:
        if chunk.choices and chunk.choices[0].delta.content:
            content = chunk.choices[0].delta.content
            full_response += content
            yield content

    # 更新状态用于后续处理
    state["generation"] = full_response

    # Step 4: (后台) 事实提取 - 这里不阻塞流式输出
    # 可以考虑用 background task
    # 暂时跳过

"""
Philia Chat 模块 - 基于 LangGraph 的自适应情感导师

该模块实现了一个自适应 RAG (Retrieval-Augmented Generation) 系统，
根据用户意图智能路由到不同的处理分支：

1. Mentor Chat Node: 纯情感咨询，带 Profile 上下文，不查 RAG
2. Memory RAG Node: 查 Postgres 的 relationship_memories 表

参考: LangGraph Adaptive RAG (https://github.com/langchain-ai/langgraph)
"""

from app.services.chat.graph import create_chat_graph, run_chat_graph
from app.services.chat.state import AgentState

__all__ = [
    "AgentState",
    "create_chat_graph",
    "run_chat_graph",
]

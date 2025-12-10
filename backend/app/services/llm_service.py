"""
Philia LLM Service
通用 LLM 服务：提供统一的 LLM 调用接口
"""

from typing import Optional

from loguru import logger
from openai import OpenAI

from app.core.config import settings


class LLMService:
    """LLM 服务类"""

    def __init__(self):
        self._client: Optional[OpenAI] = None

    def _get_client(self) -> OpenAI:
        """获取 OpenAI 兼容客户端"""
        if self._client is None:
            self._client = OpenAI(
                api_key=settings.ARK_API_KEY,
                base_url=settings.ARK_BASE_URL,
            )
        return self._client

    def chat(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 1024,
        model: Optional[str] = None,
    ) -> str:
        """
        调用 LLM 生成回复

        Args:
            messages: 消息列表 [{"role": "user/assistant/system", "content": "..."}]
            temperature: 温度参数
            max_tokens: 最大生成 token 数
            model: 模型名称（默认使用配置的 ENDPOINT_ID）

        Returns:
            生成的回复文本
        """
        try:
            client = self._get_client()

            response = client.chat.completions.create(
                model=model or settings.ENDPOINT_ID,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
            )

            return response.choices[0].message.content or ""

        except Exception as e:
            logger.error(f"LLM chat failed: {e}")
            raise


# 全局服务实例
_llm_service: Optional[LLMService] = None


def get_llm_service() -> LLMService:
    """获取 LLM 服务单例"""
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMService()
    return _llm_service

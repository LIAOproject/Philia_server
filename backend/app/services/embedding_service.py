"""
Philia Embedding Service
向量嵌入服务：使用豆包 Embedding Large 模型生成文本向量

模型信息:
- 模型名称: Doubao-embedding-large
- 向量维度: 1024 维
- 最大输入: 4096 tokens
"""

from typing import Optional

from loguru import logger
from openai import OpenAI

from app.core.config import settings

# 豆包 Embedding Large 向量维度
EMBEDDING_DIMENSION = 1024


class EmbeddingService:
    """向量嵌入服务"""

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

    def get_embedding(self, text: str) -> list[float]:
        """
        获取文本的向量嵌入

        Args:
            text: 输入文本 (最大 4096 tokens)

        Returns:
            1024 维向量
        """
        if not text or not text.strip():
            # 返回零向量
            return [0.0] * EMBEDDING_DIMENSION

        try:
            client = self._get_client()

            response = client.embeddings.create(
                model=settings.EMBEDDING_ENDPOINT_ID,
                input=text,
                encoding_format="float",
            )

            embedding = response.data[0].embedding
            logger.debug(f"Generated embedding for text ({len(text)} chars)")

            return embedding

        except Exception as e:
            logger.error(f"Embedding generation failed: {e}")
            # 返回零向量作为降级方案
            return [0.0] * EMBEDDING_DIMENSION

    def get_embeddings_batch(self, texts: list[str]) -> list[list[float]]:
        """
        批量获取文本的向量嵌入

        Args:
            texts: 输入文本列表

        Returns:
            向量列表
        """
        if not texts:
            return []

        # 过滤空文本
        valid_texts = [t if t and t.strip() else " " for t in texts]

        try:
            client = self._get_client()

            response = client.embeddings.create(
                model=settings.EMBEDDING_ENDPOINT_ID,
                input=valid_texts,
                encoding_format="float",
            )

            # 按照原始顺序返回
            embeddings = [item.embedding for item in response.data]
            logger.info(f"Generated {len(embeddings)} embeddings in batch")

            return embeddings

        except Exception as e:
            logger.error(f"Batch embedding generation failed: {e}")
            # 返回零向量作为降级方案
            return [[0.0] * EMBEDDING_DIMENSION for _ in texts]


# 全局服务实例
_embedding_service: Optional[EmbeddingService] = None


def get_embedding_service() -> EmbeddingService:
    """获取 Embedding 服务单例"""
    global _embedding_service
    if _embedding_service is None:
        _embedding_service = EmbeddingService()
    return _embedding_service


# 便捷函数
def get_embedding(text: str) -> list[float]:
    """获取文本向量嵌入"""
    return get_embedding_service().get_embedding(text)


def get_embeddings_batch(texts: list[str]) -> list[list[float]]:
    """批量获取文本向量嵌入"""
    return get_embedding_service().get_embeddings_batch(texts)

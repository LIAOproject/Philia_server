"""
Relation-OS AI 客户端
封装火山引擎豆包 Seed 1.6 Pro Vision 模型调用

支持两种调用方式:
1. 火山方舟 SDK (volcengine-ark-runtime) - 推荐
2. OpenAI 兼容模式 (openai SDK)
"""

import base64
import json
from typing import Optional

from loguru import logger

from app.core.config import settings
from app.schemas.relationship import AIAnalysisResult

# ========================
# System Prompt 定义
# ========================

ANALYSIS_SYSTEM_PROMPT = """你是一位精通中文互联网社交潜台词的情感分析师。你的任务是从用户上传的图片中提取"目标对象"的信息。

## 视觉锚定规则 (针对中文 APP)

### 微信/QQ 聊天截图:
- 右侧气泡 = User (我/用户)
- 左侧气泡 = Target (目标对象/对方)
- 注意时间戳、红包、表情包等细节

### 探探/Soul 主页截图:
- 识别主页标签 (如: 健身、旅行、宠物)
- 星座图标
- 距离显示
- 个人简介文字
- 照片风格分析

### 小红书截图:
- 用户昵称和标签
- 笔记内容
- 评论互动

### 普通照片:
- 人物外貌特征
- 穿搭风格
- 场景环境 (推断生活方式)
- 照片"含金量" (精修程度、场景档次)

## 深度分析要求

1. **情绪识别** (中文语境):
   - 积极: 撒娇、调情、热情、关心
   - 中性: 敷衍、客气、试探
   - 消极: 阴阳怪气、指责、冷淡、已读不回

2. **潜台词分析**:
   - "在干嘛" → 想你了/试探你在做什么
   - "随便" → 可能不满/懒得解释
   - "哦" → 敷衍/没兴趣
   - 识别emoji的情绪含义

3. **关键信息提取**:
   - 姓名、年龄、职业、学历
   - 兴趣爱好
   - 生活方式线索
   - 关系状态信号

4. **Red Flags (危险信号)**:
   - 回复速度骤降
   - 话题回避
   - 过度索取
   - 不一致的陈述

5. **Green Flags (积极信号)**:
   - 主动分享日常
   - 记得细节
   - 规划未来
   - 情绪价值提供

## 输出格式

严格按照以下 JSON Schema 输出，不要添加任何额外文字:

```json
{
  "image_type": "wechat|qq|tantan|soul|xiaohongshu|photo|unknown",
  "confidence": 0.0-1.0,
  "profile_updates": {
    "tags_to_add": ["标签1", "标签2"],
    "mbti": "XXXX 或 null",
    "zodiac": "星座 或 null",
    "age_range": "年龄范围 或 null",
    "occupation": "职业 或 null",
    "location": "地点 或 null",
    "appearance_updates": {"特征": "描述"},
    "personality_updates": {"特征": "描述"},
    "likes_to_add": ["喜好1"],
    "dislikes_to_add": ["厌恶1"]
  },
  "new_memories": [
    {
      "happened_at": "ISO时间格式 或 null",
      "content_summary": "内容摘要",
      "sentiment": "情绪类型",
      "sentiment_score": -10到10的整数,
      "key_event": "关键事件 或 null",
      "topics": ["话题1", "话题2"],
      "subtext": "潜台词分析",
      "red_flags": ["危险信号"],
      "green_flags": ["积极信号"],
      "conversation_fingerprint": "对话首尾句MD5用于去重"
    }
  ],
  "raw_text_extracted": "从图片中提取的原始文字",
  "analysis_notes": "分析备注"
}
```

注意:
- 如果图片不清晰或无法识别，confidence 设为较低值
- 只提取能确定的信息，不确定的字段设为 null
- new_memories 可以是空数组 (如果图片是照片而非对话)
- conversation_fingerprint 用于去重，取对话第一句和最后一句的组合
"""


class DoubaoClient:
    """
    豆包 Vision 模型客户端
    封装火山引擎 API 调用
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        endpoint_id: Optional[str] = None,
        base_url: Optional[str] = None,
    ):
        """
        初始化客户端

        Args:
            api_key: 火山方舟 API Key (ARK_API_KEY)
            endpoint_id: 推理接入点 ID (火山引擎控制台获取)
            base_url: API 基础 URL
        """
        self.api_key = api_key or settings.ARK_API_KEY
        self.endpoint_id = endpoint_id or settings.ENDPOINT_ID
        self.base_url = base_url or settings.ARK_BASE_URL

        if not self.api_key:
            logger.warning("ARK_API_KEY 未配置，AI 功能将不可用")

        if not self.endpoint_id:
            logger.warning("ENDPOINT_ID 未配置，需要在火山引擎控制台创建推理接入点")

        self._client = None

    def _get_client(self):
        """延迟初始化 OpenAI 客户端 (兼容模式)"""
        if self._client is None:
            try:
                from openai import OpenAI

                self._client = OpenAI(
                    api_key=self.api_key,
                    base_url=self.base_url,
                )
            except ImportError:
                logger.error("openai 库未安装，请运行: pip install openai")
                raise

        return self._client

    def _encode_image_to_base64(self, image_bytes: bytes) -> str:
        """将图片字节转换为 base64 编码"""
        return base64.standard_b64encode(image_bytes).decode("utf-8")

    def _detect_image_mime_type(self, image_bytes: bytes) -> str:
        """检测图片 MIME 类型"""
        # 检查文件头魔数
        if image_bytes[:8] == b"\x89PNG\r\n\x1a\n":
            return "image/png"
        elif image_bytes[:2] == b"\xff\xd8":
            return "image/jpeg"
        elif image_bytes[:6] in (b"GIF87a", b"GIF89a"):
            return "image/gif"
        elif image_bytes[:4] == b"RIFF" and image_bytes[8:12] == b"WEBP":
            return "image/webp"
        else:
            # 默认返回 jpeg
            return "image/jpeg"

    async def analyze_image(
        self,
        image_bytes: bytes,
        custom_prompt: Optional[str] = None,
    ) -> AIAnalysisResult:
        """
        分析图片并返回结构化结果

        Args:
            image_bytes: 图片二进制数据
            custom_prompt: 自定义用户提示 (可选)

        Returns:
            AIAnalysisResult: 分析结果
        """
        if not self.api_key or not self.endpoint_id:
            raise ValueError("API Key 或 Endpoint ID 未配置")

        # 编码图片
        image_base64 = self._encode_image_to_base64(image_bytes)
        mime_type = self._detect_image_mime_type(image_bytes)

        # 构建消息
        user_content = [
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:{mime_type};base64,{image_base64}",
                },
            },
            {
                "type": "text",
                "text": custom_prompt or "请分析这张图片，按照要求的 JSON 格式输出结果。",
            },
        ]

        messages = [
            {"role": "system", "content": ANALYSIS_SYSTEM_PROMPT},
            {"role": "user", "content": user_content},
        ]

        try:
            # 使用 OpenAI 兼容模式调用
            client = self._get_client()

            # 火山引擎的模型名需要使用 endpoint_id
            response = client.chat.completions.create(
                model=self.endpoint_id,  # 使用接入点 ID 作为模型名
                messages=messages,
                max_tokens=4096,
                temperature=0.3,  # 降低随机性，提高结构化输出一致性
                response_format={"type": "json_object"},  # 强制 JSON 输出
            )

            # 解析响应
            content = response.choices[0].message.content
            logger.info(f"AI 响应原始内容: {content[:500]}...")

            # 解析 JSON
            result_dict = json.loads(content)

            # 转换为 Pydantic 模型
            return AIAnalysisResult(**result_dict)

        except json.JSONDecodeError as e:
            logger.error(f"AI 响应 JSON 解析失败: {e}")
            # 返回默认结果
            return AIAnalysisResult(
                image_type="unknown",
                confidence=0.0,
                analysis_notes=f"JSON 解析失败: {str(e)}",
            )

        except Exception as e:
            logger.error(f"AI 分析失败: {e}")
            raise

    async def analyze_image_with_ark_sdk(
        self,
        image_bytes: bytes,
        custom_prompt: Optional[str] = None,
    ) -> AIAnalysisResult:
        """
        使用火山方舟官方 SDK 分析图片 (备选方案)

        Args:
            image_bytes: 图片二进制数据
            custom_prompt: 自定义用户提示 (可选)

        Returns:
            AIAnalysisResult: 分析结果
        """
        try:
            from volcenginesdkarkruntime import Ark

            # 初始化 Ark 客户端
            ark_client = Ark(api_key=self.api_key)

            # 编码图片
            image_base64 = self._encode_image_to_base64(image_bytes)
            mime_type = self._detect_image_mime_type(image_bytes)

            # 构建消息
            user_content = [
                {
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:{mime_type};base64,{image_base64}",
                    },
                },
                {
                    "type": "text",
                    "text": custom_prompt or "请分析这张图片，按照要求的 JSON 格式输出结果。",
                },
            ]

            # 调用模型
            response = ark_client.chat.completions.create(
                model=self.endpoint_id,
                messages=[
                    {"role": "system", "content": ANALYSIS_SYSTEM_PROMPT},
                    {"role": "user", "content": user_content},
                ],
                max_tokens=4096,
                temperature=0.3,
            )

            # 解析响应
            content = response.choices[0].message.content
            result_dict = json.loads(content)

            return AIAnalysisResult(**result_dict)

        except ImportError:
            logger.error("volcenginesdkarkruntime 未安装，请运行: pip install volcengine-ark-runtime")
            raise

        except Exception as e:
            logger.error(f"Ark SDK 分析失败: {e}")
            raise


# ========================
# 便捷函数
# ========================

# 全局客户端实例
_doubao_client: Optional[DoubaoClient] = None


def get_doubao_client() -> DoubaoClient:
    """获取豆包客户端单例"""
    global _doubao_client
    if _doubao_client is None:
        _doubao_client = DoubaoClient()
    return _doubao_client


async def analyze_image_with_doubao(
    image_bytes: bytes,
    custom_prompt: Optional[str] = None,
) -> AIAnalysisResult:
    """
    便捷函数: 使用豆包分析图片

    Args:
        image_bytes: 图片二进制数据
        custom_prompt: 自定义提示 (可选)

    Returns:
        AIAnalysisResult: 分析结果
    """
    client = get_doubao_client()
    return await client.analyze_image(image_bytes, custom_prompt)

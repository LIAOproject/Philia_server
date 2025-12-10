"""
Philia API - 聊天模块路由
AI 情感导师 Chatbot 相关接口
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.chat import AIMentor, Chatbot, ChatMessage
from app.models.relationship import TargetProfile
from app.schemas.chat import (
    AIMentorCreate,
    AIMentorListResponse,
    AIMentorResponse,
    AIMentorUpdate,
    ChatbotCreate,
    ChatbotDebugSettings,
    ChatbotDebugSettingsUpdate,
    ChatbotDetailResponse,
    ChatbotListResponse,
    ChatbotResponse,
    ChatbotUpdate,
    ChatMessageListResponse,
    ChatMessageResponse,
    RAGCorpusItem,
    RAGSettings,
    SendMessageRequest,
    SendMessageResponse,
)
from app.schemas.relationship import MessageResponse
from app.services.chat_service import get_chat_service

router = APIRouter(prefix="/chat", tags=["Chat"])


# ========================
# AI Mentor 路由
# ========================


@router.post("/mentors/", response_model=AIMentorResponse, status_code=status.HTTP_201_CREATED)
async def create_mentor(
    mentor_data: AIMentorCreate,
    db: AsyncSession = Depends(get_db),
) -> AIMentorResponse:
    """创建 AI 导师"""
    mentor = AIMentor(
        name=mentor_data.name,
        description=mentor_data.description,
        system_prompt_template=mentor_data.system_prompt_template,
        icon_url=mentor_data.icon_url,
        style_tag=mentor_data.style_tag,
        sort_order=mentor_data.sort_order,
    )

    # 设置 RAG 配置 (如果提供)
    if mentor_data.default_rag_settings:
        mentor.default_rag_settings = mentor_data.default_rag_settings.model_dump()
    if mentor_data.default_rag_corpus:
        mentor.default_rag_corpus = [item.model_dump() for item in mentor_data.default_rag_corpus]

    db.add(mentor)
    await db.commit()
    await db.refresh(mentor)

    return AIMentorResponse.model_validate(mentor)


@router.get("/mentors/", response_model=AIMentorListResponse)
async def list_mentors(
    active_only: bool = Query(True, description="只返回激活的导师"),
    db: AsyncSession = Depends(get_db),
) -> AIMentorListResponse:
    """获取 AI 导师列表"""
    query = select(AIMentor)

    if active_only:
        query = query.where(AIMentor.is_active == True)

    query = query.order_by(AIMentor.sort_order, AIMentor.created_at)

    result = await db.execute(query)
    mentors = result.scalars().all()

    return AIMentorListResponse(
        total=len(mentors),
        items=[AIMentorResponse.model_validate(m) for m in mentors],
    )


@router.get("/mentors/{mentor_id}", response_model=AIMentorResponse)
async def get_mentor(
    mentor_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> AIMentorResponse:
    """获取单个 AI 导师详情"""
    query = select(AIMentor).where(AIMentor.id == mentor_id)
    result = await db.execute(query)
    mentor = result.scalar_one_or_none()

    if not mentor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"导师 {mentor_id} 不存在",
        )

    return AIMentorResponse.model_validate(mentor)


@router.patch("/mentors/{mentor_id}", response_model=AIMentorResponse)
async def update_mentor(
    mentor_id: UUID,
    mentor_data: AIMentorUpdate,
    db: AsyncSession = Depends(get_db),
) -> AIMentorResponse:
    """更新 AI 导师"""
    query = select(AIMentor).where(AIMentor.id == mentor_id)
    result = await db.execute(query)
    mentor = result.scalar_one_or_none()

    if not mentor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"导师 {mentor_id} 不存在",
        )

    update_data = mentor_data.model_dump(exclude_unset=True)

    # 特殊处理 RAG 字段：转换 Pydantic 模型为字典
    if "default_rag_settings" in update_data and update_data["default_rag_settings"]:
        update_data["default_rag_settings"] = mentor_data.default_rag_settings.model_dump()
    if "default_rag_corpus" in update_data and update_data["default_rag_corpus"]:
        update_data["default_rag_corpus"] = [item.model_dump() for item in mentor_data.default_rag_corpus]

    for field, value in update_data.items():
        setattr(mentor, field, value)

    await db.commit()
    await db.refresh(mentor)

    return AIMentorResponse.model_validate(mentor)


# ========================
# Chatbot 路由
# ========================


@router.post("/chatbots/", response_model=ChatbotResponse, status_code=status.HTTP_201_CREATED)
async def create_chatbot(
    chatbot_data: ChatbotCreate,
    db: AsyncSession = Depends(get_db),
) -> ChatbotResponse:
    """创建 Chatbot 会话"""
    # 验证 Target 存在
    target_query = select(TargetProfile).where(TargetProfile.id == chatbot_data.target_id)
    target_result = await db.execute(target_query)
    target = target_result.scalar_one_or_none()

    if not target:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"对象 {chatbot_data.target_id} 不存在",
        )

    # 验证 Mentor 存在
    mentor_query = select(AIMentor).where(AIMentor.id == chatbot_data.mentor_id)
    mentor_result = await db.execute(mentor_query)
    mentor = mentor_result.scalar_one_or_none()

    if not mentor:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"导师 {chatbot_data.mentor_id} 不存在",
        )

    # 生成默认标题
    title = chatbot_data.title or f"与 {mentor.name} 聊聊 {target.name}"

    chatbot = Chatbot(
        target_id=chatbot_data.target_id,
        mentor_id=chatbot_data.mentor_id,
        title=title,
    )

    db.add(chatbot)
    await db.commit()
    await db.refresh(chatbot)

    return ChatbotResponse(
        id=chatbot.id,
        target_id=chatbot.target_id,
        mentor_id=chatbot.mentor_id,
        title=chatbot.title,
        status=chatbot.status,
        created_at=chatbot.created_at,
        updated_at=chatbot.updated_at,
        target_name=target.name,
        mentor_name=mentor.name,
        mentor_icon_url=mentor.icon_url,
        message_count=0,
    )


@router.get("/chatbots/", response_model=ChatbotListResponse)
async def list_chatbots(
    target_id: Optional[UUID] = Query(None, description="按对象筛选"),
    status_filter: Optional[str] = Query(None, description="按状态筛选"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
) -> ChatbotListResponse:
    """获取 Chatbot 列表"""
    query = select(Chatbot)

    if target_id:
        query = query.where(Chatbot.target_id == target_id)

    if status_filter:
        query = query.where(Chatbot.status == status_filter)

    # 统计总数
    count_query = select(func.count()).select_from(query.subquery())
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页
    query = query.order_by(Chatbot.updated_at.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    chatbots = result.scalars().all()

    # 获取关联信息
    items = []
    for chatbot in chatbots:
        # 获取 target 名称
        target_query = select(TargetProfile.name).where(TargetProfile.id == chatbot.target_id)
        target_result = await db.execute(target_query)
        target_name = target_result.scalar()

        # 获取 mentor 信息
        mentor_query = select(AIMentor.name, AIMentor.icon_url).where(AIMentor.id == chatbot.mentor_id)
        mentor_result = await db.execute(mentor_query)
        mentor_row = mentor_result.first()
        mentor_name, mentor_icon_url = mentor_row if mentor_row else (None, None)

        # 统计消息数
        msg_count_query = select(func.count()).where(ChatMessage.chatbot_id == chatbot.id)
        msg_count_result = await db.execute(msg_count_query)
        message_count = msg_count_result.scalar() or 0

        items.append(
            ChatbotResponse(
                id=chatbot.id,
                target_id=chatbot.target_id,
                mentor_id=chatbot.mentor_id,
                title=chatbot.title,
                status=chatbot.status,
                created_at=chatbot.created_at,
                updated_at=chatbot.updated_at,
                target_name=target_name,
                mentor_name=mentor_name,
                mentor_icon_url=mentor_icon_url,
                message_count=message_count,
            )
        )

    return ChatbotListResponse(total=total, items=items)


@router.get("/chatbots/{chatbot_id}", response_model=ChatbotDetailResponse)
async def get_chatbot(
    chatbot_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> ChatbotDetailResponse:
    """获取 Chatbot 详情 (包含最近消息)"""
    query = select(Chatbot).where(Chatbot.id == chatbot_id)
    result = await db.execute(query)
    chatbot = result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    # 获取关联信息
    target_query = select(TargetProfile.name).where(TargetProfile.id == chatbot.target_id)
    target_result = await db.execute(target_query)
    target_name = target_result.scalar()

    mentor_query = select(AIMentor.name, AIMentor.icon_url).where(AIMentor.id == chatbot.mentor_id)
    mentor_result = await db.execute(mentor_query)
    mentor_row = mentor_result.first()
    mentor_name, mentor_icon_url = mentor_row if mentor_row else (None, None)

    # 获取最近消息
    messages_query = (
        select(ChatMessage)
        .where(ChatMessage.chatbot_id == chatbot_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(50)
    )
    messages_result = await db.execute(messages_query)
    messages = list(reversed(messages_result.scalars().all()))

    recent_messages = [ChatMessageResponse.model_validate(m) for m in messages]

    return ChatbotDetailResponse(
        id=chatbot.id,
        target_id=chatbot.target_id,
        mentor_id=chatbot.mentor_id,
        title=chatbot.title,
        status=chatbot.status,
        created_at=chatbot.created_at,
        updated_at=chatbot.updated_at,
        target_name=target_name,
        mentor_name=mentor_name,
        mentor_icon_url=mentor_icon_url,
        message_count=len(messages),
        recent_messages=recent_messages,
    )


@router.patch("/chatbots/{chatbot_id}", response_model=ChatbotResponse)
async def update_chatbot(
    chatbot_id: UUID,
    chatbot_data: ChatbotUpdate,
    db: AsyncSession = Depends(get_db),
) -> ChatbotResponse:
    """更新 Chatbot"""
    query = select(Chatbot).where(Chatbot.id == chatbot_id)
    result = await db.execute(query)
    chatbot = result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    update_data = chatbot_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(chatbot, field, value)

    await db.commit()
    await db.refresh(chatbot)

    return ChatbotResponse.model_validate(chatbot)


@router.delete("/chatbots/{chatbot_id}", response_model=MessageResponse)
async def delete_chatbot(
    chatbot_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    """删除 Chatbot (级联删除所有消息)"""
    query = select(Chatbot).where(Chatbot.id == chatbot_id)
    result = await db.execute(query)
    chatbot = result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    await db.delete(chatbot)
    await db.commit()

    return MessageResponse(success=True, message="会话已删除")


# ========================
# 消息路由
# ========================


@router.get("/chatbots/{chatbot_id}/messages", response_model=ChatMessageListResponse)
async def list_messages(
    chatbot_id: UUID,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
) -> ChatMessageListResponse:
    """获取聊天消息列表"""
    # 验证 chatbot 存在
    chatbot_query = select(Chatbot).where(Chatbot.id == chatbot_id)
    chatbot_result = await db.execute(chatbot_query)
    if not chatbot_result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    # 统计总数
    count_query = select(func.count()).where(ChatMessage.chatbot_id == chatbot_id)
    total_result = await db.execute(count_query)
    total = total_result.scalar() or 0

    # 分页查询 (按时间正序)
    query = (
        select(ChatMessage)
        .where(ChatMessage.chatbot_id == chatbot_id)
        .order_by(ChatMessage.created_at)
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(query)
    messages = result.scalars().all()

    return ChatMessageListResponse(
        total=total,
        items=[ChatMessageResponse.model_validate(m) for m in messages],
    )


@router.post("/chatbots/{chatbot_id}/send", response_model=SendMessageResponse)
async def send_message(
    chatbot_id: UUID,
    request: SendMessageRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
) -> SendMessageResponse:
    """
    发送消息并获取 AI 回复

    处理流程:
    1. 获取上下文 (Target profile, RAG memories)
    2. 构建 prompt
    3. 调用 LLM
    4. 保存消息
    5. 后台分析是否有新事实
    """
    # 获取 chatbot
    chatbot_query = select(Chatbot).where(Chatbot.id == chatbot_id)
    chatbot_result = await db.execute(chatbot_query)
    chatbot = chatbot_result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    # 获取 mentor
    mentor_query = select(AIMentor).where(AIMentor.id == chatbot.mentor_id)
    mentor_result = await db.execute(mentor_query)
    mentor = mentor_result.scalar_one_or_none()

    if not mentor:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="导师配置错误",
        )

    # 保存用户消息
    user_message = ChatMessage(
        chatbot_id=chatbot_id,
        role="user",
        content=request.message,
    )
    db.add(user_message)
    await db.commit()
    await db.refresh(user_message)

    # 获取服务
    chat_service = get_chat_service()

    # 获取上下文
    context = await chat_service.get_chat_context(
        db=db,
        chatbot=chatbot,
        user_message=request.message,
    )

    # 构建 prompt 和消息 (使用自定义 prompt 如果有的话)
    system_prompt = chat_service.build_system_prompt(
        mentor, context, custom_prompt=chatbot.custom_system_prompt
    )
    messages = chat_service.build_messages(system_prompt, context, request.message)

    # 生成回复
    response_content = await chat_service.generate_response(messages, stream=False)

    # 保存 AI 回复
    assistant_message = ChatMessage(
        chatbot_id=chatbot_id,
        role="assistant",
        content=response_content,
    )
    db.add(assistant_message)
    await db.commit()
    await db.refresh(assistant_message)

    # 后台任务: 分析是否有新事实
    async def analyze_task():
        async with get_db() as session:
            await chat_service.analyze_for_new_facts(
                db=session,
                target_id=chatbot.target_id,
                user_message=request.message,
                assistant_response=response_content,
            )

    # 注意: BackgroundTasks 在这里用法需要调整
    # 因为异步上下文的限制，我们先同步执行分析
    memory_created = await chat_service.analyze_for_new_facts(
        db=db,
        target_id=chatbot.target_id,
        user_message=request.message,
        assistant_response=response_content,
    )

    return SendMessageResponse(
        user_message=ChatMessageResponse.model_validate(user_message),
        assistant_message=ChatMessageResponse.model_validate(assistant_message),
        memories_retrieved=len(context.retrieved_memories),
        memory_created=memory_created,
    )


@router.post("/chatbots/{chatbot_id}/send/stream")
async def send_message_stream(
    chatbot_id: UUID,
    request: SendMessageRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    发送消息并以流式方式获取 AI 回复

    返回 Server-Sent Events (SSE) 格式
    """
    # 获取 chatbot
    chatbot_query = select(Chatbot).where(Chatbot.id == chatbot_id)
    chatbot_result = await db.execute(chatbot_query)
    chatbot = chatbot_result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    # 获取 mentor
    mentor_query = select(AIMentor).where(AIMentor.id == chatbot.mentor_id)
    mentor_result = await db.execute(mentor_query)
    mentor = mentor_result.scalar_one_or_none()

    if not mentor:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="导师配置错误",
        )

    # 保存用户消息
    user_message = ChatMessage(
        chatbot_id=chatbot_id,
        role="user",
        content=request.message,
    )
    db.add(user_message)
    await db.commit()
    await db.refresh(user_message)

    chat_service = get_chat_service()

    # 获取上下文
    context = await chat_service.get_chat_context(
        db=db,
        chatbot=chatbot,
        user_message=request.message,
    )

    # 构建 prompt (使用自定义 prompt 如果有的话)
    system_prompt = chat_service.build_system_prompt(
        mentor, context, custom_prompt=chatbot.custom_system_prompt
    )
    messages = chat_service.build_messages(system_prompt, context, request.message)

    async def generate():
        """SSE 生成器"""
        full_response = ""

        try:
            async for chunk in await chat_service.generate_response(messages, stream=True):
                full_response += chunk
                yield f"data: {chunk}\n\n"

            # 保存完整回复
            assistant_message = ChatMessage(
                chatbot_id=chatbot_id,
                role="assistant",
                content=full_response,
            )
            db.add(assistant_message)
            await db.commit()

            # 发送完成信号
            yield f"data: [DONE]\n\n"

        except Exception as e:
            yield f"data: [ERROR] {str(e)}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )


# ========================
# 调试设置路由
# ========================


@router.get("/chatbots/{chatbot_id}/debug", response_model=ChatbotDebugSettings)
async def get_debug_settings(
    chatbot_id: UUID,
    db: AsyncSession = Depends(get_db),
) -> ChatbotDebugSettings:
    """
    获取 Chatbot 调试设置

    返回系统提示词、RAG 设置和语料库
    """
    # 获取 chatbot
    chatbot_query = select(Chatbot).where(Chatbot.id == chatbot_id)
    chatbot_result = await db.execute(chatbot_query)
    chatbot = chatbot_result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    # 获取 mentor
    mentor_query = select(AIMentor).where(AIMentor.id == chatbot.mentor_id)
    mentor_result = await db.execute(mentor_query)
    mentor = mentor_result.scalar_one_or_none()

    if not mentor:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="导师配置错误",
        )

    # 获取 target
    target_query = select(TargetProfile).where(TargetProfile.id == chatbot.target_id)
    target_result = await db.execute(target_query)
    target = target_result.scalar_one_or_none()

    # 尝试渲染生效的系统提示词
    effective_prompt = None
    try:
        chat_service = get_chat_service()
        # 创建一个模拟上下文来渲染 prompt
        if target:
            profile_summary = chat_service._build_profile_summary(target)
            preferences = chat_service._build_preferences_summary(target)

            # 使用自定义 prompt 或 mentor 模板
            template = chatbot.custom_system_prompt or mentor.system_prompt_template

            effective_prompt = template.format(
                target_name=target.name,
                profile_summary=profile_summary,
                preferences=preferences,
                context="[RAG 检索结果将在这里显示]",
            )
    except Exception:
        effective_prompt = "[渲染失败 - 请检查模板语法]"

    # 构建 RAG 设置
    rag_settings = chatbot.rag_settings or {
        "enabled": True,
        "max_memories": 5,
        "max_recent_messages": 10,
        "time_decay_factor": 0.1,
        "min_relevance_score": 0.0,
    }

    # 构建 RAG 语料库
    rag_corpus = chatbot.rag_corpus or []

    return ChatbotDebugSettings(
        id=chatbot.id,
        mentor_system_prompt_template=mentor.system_prompt_template,
        custom_system_prompt=chatbot.custom_system_prompt,
        effective_system_prompt=effective_prompt,
        rag_settings=RAGSettings(**rag_settings),
        rag_corpus=[RAGCorpusItem(**item) for item in rag_corpus],
    )


@router.patch("/chatbots/{chatbot_id}/debug", response_model=ChatbotDebugSettings)
async def update_debug_settings(
    chatbot_id: UUID,
    settings_update: ChatbotDebugSettingsUpdate,
    db: AsyncSession = Depends(get_db),
) -> ChatbotDebugSettings:
    """
    更新 Chatbot 调试设置

    可更新: 自定义系统提示词、RAG 设置、RAG 语料库
    """
    # 获取 chatbot
    chatbot_query = select(Chatbot).where(Chatbot.id == chatbot_id)
    chatbot_result = await db.execute(chatbot_query)
    chatbot = chatbot_result.scalar_one_or_none()

    if not chatbot:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"会话 {chatbot_id} 不存在",
        )

    # 更新字段
    if settings_update.custom_system_prompt is not None:
        # 空字符串表示清除自定义 prompt
        chatbot.custom_system_prompt = settings_update.custom_system_prompt or None

    if settings_update.rag_settings is not None:
        chatbot.rag_settings = settings_update.rag_settings.model_dump()

    if settings_update.rag_corpus is not None:
        chatbot.rag_corpus = [item.model_dump() for item in settings_update.rag_corpus]

    await db.commit()
    await db.refresh(chatbot)

    # 返回更新后的设置
    return await get_debug_settings(chatbot_id, db)

'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { format } from 'date-fns'
import { zhCN } from 'date-fns/locale'
import { Send, Loader2, Sparkles, MessageCircle, Settings } from 'lucide-react'

import { chatApi } from '@/lib/api'
import { ChatbotDebugPanel } from '@/components/features/chatbot-debug-panel'
import { ChatMessage, Chatbot, ChatbotDetail } from '@/types'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { useToast } from '@/hooks/use-toast'

interface ChatDetailPanelProps {
  chatbot: Chatbot | null
  className?: string
}

export function ChatDetailPanel({ chatbot, className }: ChatDetailPanelProps) {
  if (!chatbot) {
    return (
      <div className={cn('flex flex-col h-full items-center justify-center', className)}>
        <div className="text-center text-muted-foreground">
          <MessageCircle className="h-16 w-16 mx-auto mb-4 opacity-30" />
          <p className="text-lg font-medium">选择一个对话</p>
          <p className="text-sm mt-1">或创建新的对话开始咨询</p>
        </div>
      </div>
    )
  }

  return <ChatContent chatbotId={chatbot.id} className={className} />
}

// 聊天内容组件
function ChatContent({ chatbotId, className }: { chatbotId: string; className?: string }) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [inputValue, setInputValue] = useState('')
  const [isStreaming, setIsStreaming] = useState(false)
  const [streamingContent, setStreamingContent] = useState('')
  const [debugPanelOpen, setDebugPanelOpen] = useState(false)
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const streamingContentRef = useRef('')  // 用于在 onDone 中获取最新内容
  const hasAddedMessageRef = useRef(false)  // 防止重复添加消息

  // 获取 chatbot 详情（包含最近消息）
  const { data: chatbotDetail, isLoading } = useQuery({
    queryKey: ['chatbot', chatbotId],
    queryFn: () => chatApi.getChatbot(chatbotId),
    enabled: !!chatbotId,
    refetchOnWindowFocus: false,
    refetchOnReconnect: false,
    // 移除 staleTime: Infinity，让组件重新挂载时能获取最新消息
  })

  // 切换对话时重置消息
  const prevChatbotIdRef = useRef<string | null>(null)

  useEffect(() => {
    // 检测是否切换了对话
    if (chatbotId !== prevChatbotIdRef.current) {
      // 切换对话时先清空消息，等待新数据
      setMessages([])
      setDebugPanelOpen(false)  // 关闭设置面板
      prevChatbotIdRef.current = chatbotId
      // 强制重新获取最新消息
      queryClient.invalidateQueries({ queryKey: ['chatbot', chatbotId] })
    }
  }, [chatbotId, queryClient])

  // 当 chatbotDetail 加载完成时设置消息
  useEffect(() => {
    if (chatbotDetail?.recent_messages && messages.length === 0) {
      setMessages(chatbotDetail.recent_messages)
    }
  }, [chatbotDetail]) // 故意不依赖 messages，只在 chatbotDetail 变化时触发

  // 滚动到底部
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  useEffect(() => {
    scrollToBottom()
  }, [messages, streamingContent, scrollToBottom])

  // 发送消息 (流式)
  const handleSend = useCallback(async () => {
    if (!inputValue.trim() || isStreaming || !chatbotDetail) return

    const messageToSend = inputValue
    setInputValue('')

    // 添加用户消息到 UI (乐观更新)
    const tempUserMessage: ChatMessage = {
      id: `temp-user-${Date.now()}`,
      chatbot_id: chatbotId,
      role: 'user',
      content: messageToSend,
      created_at: new Date().toISOString(),
    }
    setMessages((prev) => [...prev, tempUserMessage])

    // 开始流式响应
    setIsStreaming(true)
    setStreamingContent('')
    streamingContentRef.current = ''
    hasAddedMessageRef.current = false  // 重置标志

    await chatApi.sendMessageStream(
      chatbotId,
      messageToSend,
      // onChunk
      (chunk) => {
        streamingContentRef.current += chunk
        setStreamingContent(streamingContentRef.current)
      },
      // onDone
      () => {
        // 防止重复添加消息
        if (hasAddedMessageRef.current) return
        hasAddedMessageRef.current = true

        // 使用 ref 中的内容，避免闭包问题
        const content = streamingContentRef.current
        if (content) {
          const assistantMessage: ChatMessage = {
            id: `temp-assistant-${Date.now()}`,
            chatbot_id: chatbotId,
            role: 'assistant',
            content: content,
            created_at: new Date().toISOString(),
          }
          setMessages((msgs) => [...msgs, assistantMessage])
        }
        setStreamingContent('')
        streamingContentRef.current = ''
        setIsStreaming(false)
        // 只更新列表的消息数，不重新获取详情（避免消息重复）
        queryClient.invalidateQueries({ queryKey: ['chatbots'] })
      },
      // onError
      (error) => {
        setIsStreaming(false)
        setStreamingContent('')
        streamingContentRef.current = ''
        toast({
          title: '发送失败',
          description: error,
          variant: 'destructive',
        })
      }
    )
  }, [inputValue, isStreaming, chatbotId, chatbotDetail, queryClient, toast])

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  if (isLoading) {
    return (
      <div className={cn('flex flex-col h-full items-center justify-center', className)}>
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  if (!chatbotDetail) {
    return (
      <div className={cn('flex flex-col h-full items-center justify-center', className)}>
        <p className="text-muted-foreground">对话不存在</p>
      </div>
    )
  }

  return (
    <div className={cn('flex flex-col h-full', className)}>
      {/* 聊天头部 */}
      <div className="flex items-center gap-3 p-3 border-b bg-background/95 backdrop-blur shrink-0">
        <Avatar className="h-9 w-9">
          {chatbotDetail.mentor_icon_url ? (
            <AvatarImage src={chatbotDetail.mentor_icon_url} />
          ) : null}
          <AvatarFallback>
            <Sparkles className="h-4 w-4" />
          </AvatarFallback>
        </Avatar>
        <div className="min-w-0 flex-1">
          <h2 className="font-medium text-sm truncate">{chatbotDetail.mentor_name}</h2>
          <p className="text-xs text-muted-foreground truncate">
            正在帮你分析与 {chatbotDetail.target_name} 的关系
          </p>
        </div>
        {/* 设置按钮 */}
        <Button
          variant="ghost"
          size="sm"
          onClick={() => setDebugPanelOpen(!debugPanelOpen)}
          className="h-8 w-8 p-0 shrink-0"
        >
          <Settings className="h-4 w-4" />
        </Button>
      </div>

      {/* 消息列表 */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && !isStreaming ? (
          <div className="flex flex-col items-center justify-center h-full text-center text-muted-foreground">
            <Sparkles className="h-10 w-10 mb-3 opacity-50" />
            <p className="font-medium">开始你的情感咨询</p>
            <p className="text-sm mt-1">
              向 {chatbotDetail.mentor_name} 倾诉吧
            </p>
          </div>
        ) : (
          messages.map((message) => (
            <MessageBubble
              key={message.id}
              message={message}
              mentorIconUrl={chatbotDetail.mentor_icon_url}
            />
          ))
        )}

        {/* AI 流式输出 */}
        {isStreaming && (
          <div className="flex items-start gap-2">
            <Avatar className="h-7 w-7 shrink-0">
              {chatbotDetail.mentor_icon_url ? (
                <AvatarImage src={chatbotDetail.mentor_icon_url} />
              ) : null}
              <AvatarFallback>
                <Sparkles className="h-3.5 w-3.5" />
              </AvatarFallback>
            </Avatar>
            <div className="max-w-[80%] bg-muted rounded-2xl rounded-tl-none px-3 py-2">
              {streamingContent ? (
                <p className="text-sm whitespace-pre-wrap">
                  {streamingContent}
                  <span className="inline-block w-1.5 h-4 bg-foreground/50 animate-pulse ml-0.5" />
                </p>
              ) : (
                <Loader2 className="h-4 w-4 animate-spin" />
              )}
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* 输入区域 */}
      <div className="p-3 border-t bg-background shrink-0">
        <div className="flex gap-2">
          <Input
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="输入你想说的话..."
            disabled={isStreaming}
            className="flex-1 h-9 text-sm"
          />
          <Button
            size="sm"
            onClick={handleSend}
            disabled={!inputValue.trim() || isStreaming}
            className="h-9 w-9 p-0"
          >
            {isStreaming ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Send className="h-4 w-4" />
            )}
          </Button>
        </div>
      </div>

      {/* 调试设置面板 - 只在打开时渲染，避免显示浮动按钮 */}
      {debugPanelOpen && (
        <ChatbotDebugPanel
          chatbotId={chatbotId}
          isOpen={debugPanelOpen}
          onToggle={() => setDebugPanelOpen(false)}
        />
      )}
    </div>
  )
}

// 消息气泡组件
interface MessageBubbleProps {
  message: ChatMessage
  mentorIconUrl?: string
}

function MessageBubble({ message, mentorIconUrl }: MessageBubbleProps) {
  const isUser = message.role === 'user'

  return (
    <div
      className={cn('flex items-start gap-2', isUser && 'flex-row-reverse')}
    >
      <Avatar className="h-7 w-7 shrink-0">
        {!isUser && mentorIconUrl ? (
          <AvatarImage src={mentorIconUrl} />
        ) : null}
        <AvatarFallback className={isUser ? 'bg-primary text-primary-foreground text-xs' : ''}>
          {isUser ? '我' : <Sparkles className="h-3.5 w-3.5" />}
        </AvatarFallback>
      </Avatar>
      <div
        className={cn(
          'max-w-[80%] rounded-2xl px-3 py-2',
          isUser
            ? 'bg-primary text-primary-foreground rounded-tr-none'
            : 'bg-muted rounded-tl-none'
        )}
      >
        <p className="text-sm whitespace-pre-wrap">{message.content}</p>
        <p
          className={cn(
            'text-xs mt-1',
            isUser ? 'text-primary-foreground/70' : 'text-muted-foreground'
          )}
        >
          {format(new Date(message.created_at), 'HH:mm', { locale: zhCN })}
        </p>
      </div>
    </div>
  )
}

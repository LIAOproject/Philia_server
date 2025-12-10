'use client'

import { useCallback, useEffect, useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { Send, Loader2, Sparkles } from 'lucide-react'
import { format } from 'date-fns'
import { zhCN } from 'date-fns/locale'

import { chatApi } from '@/lib/api'
import { ChatMessage, ChatbotDetail } from '@/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { cn } from '@/lib/utils'
import { useToast } from '@/hooks/use-toast'

interface ChatInterfaceProps {
  chatbot: ChatbotDetail
}

export function ChatInterface({ chatbot }: ChatInterfaceProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [messages, setMessages] = useState<ChatMessage[]>(
    chatbot.recent_messages || []
  )
  const [inputValue, setInputValue] = useState('')
  const [isStreaming, setIsStreaming] = useState(false)
  const [streamingContent, setStreamingContent] = useState('')
  const messagesEndRef = useRef<HTMLDivElement>(null)

  // 滚动到底部
  const scrollToBottom = useCallback(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }, [])

  useEffect(() => {
    scrollToBottom()
  }, [messages, streamingContent, scrollToBottom])

  // 发送消息 (流式)
  const handleSend = useCallback(async () => {
    if (!inputValue.trim() || isStreaming) return

    const messageToSend = inputValue
    setInputValue('')

    // 添加用户消息到 UI (乐观更新)
    const tempUserMessage: ChatMessage = {
      id: `temp-user-${Date.now()}`,
      chatbot_id: chatbot.id,
      role: 'user',
      content: messageToSend,
      created_at: new Date().toISOString(),
    }
    setMessages((prev) => [...prev, tempUserMessage])

    // 开始流式响应
    setIsStreaming(true)
    setStreamingContent('')

    await chatApi.sendMessageStream(
      chatbot.id,
      messageToSend,
      // onChunk
      (chunk) => {
        setStreamingContent((prev) => prev + chunk)
      },
      // onDone
      () => {
        setStreamingContent((prev) => {
          // 将流式内容转换为正式消息
          const assistantMessage: ChatMessage = {
            id: `temp-assistant-${Date.now()}`,
            chatbot_id: chatbot.id,
            role: 'assistant',
            content: prev,
            created_at: new Date().toISOString(),
          }
          setMessages((msgs) => [...msgs, assistantMessage])
          return ''
        })
        setIsStreaming(false)
        queryClient.invalidateQueries({ queryKey: ['chatbot', chatbot.id] })
      },
      // onError
      (error) => {
        setIsStreaming(false)
        setStreamingContent('')
        toast({
          title: '发送失败',
          description: error,
          variant: 'destructive',
        })
      }
    )
  }, [inputValue, isStreaming, chatbot.id, queryClient, toast])

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  return (
    <div className="flex flex-col h-full">
      {/* 聊天头部 */}
      <div className="flex items-center gap-3 p-4 border-b bg-background/95 backdrop-blur">
        <Avatar className="h-10 w-10">
          {chatbot.mentor_icon_url ? (
            <AvatarImage src={chatbot.mentor_icon_url} />
          ) : null}
          <AvatarFallback>
            <Sparkles className="h-5 w-5" />
          </AvatarFallback>
        </Avatar>
        <div>
          <h2 className="font-semibold">{chatbot.mentor_name}</h2>
          <p className="text-sm text-muted-foreground">
            正在帮你分析与 {chatbot.target_name} 的关系
          </p>
        </div>
      </div>

      {/* 消息列表 */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 && !isStreaming ? (
          <div className="flex flex-col items-center justify-center h-full text-center text-muted-foreground">
            <Sparkles className="h-12 w-12 mb-4" />
            <p className="text-lg font-medium">开始你的情感咨询</p>
            <p className="text-sm">
              向 {chatbot.mentor_name} 倾诉你与 {chatbot.target_name} 的故事吧
            </p>
          </div>
        ) : (
          messages.map((message) => (
            <MessageBubble
              key={message.id}
              message={message}
              mentorName={chatbot.mentor_name}
            />
          ))
        )}

        {/* AI 流式输出 */}
        {isStreaming && (
          <div className="flex items-start gap-3">
            <Avatar className="h-8 w-8">
              <AvatarFallback>
                <Sparkles className="h-4 w-4" />
              </AvatarFallback>
            </Avatar>
            <div className="max-w-[70%] bg-muted rounded-2xl rounded-tl-none px-4 py-2">
              {streamingContent ? (
                <p className="whitespace-pre-wrap">{streamingContent}<span className="inline-block w-2 h-4 bg-foreground/50 animate-pulse ml-0.5" /></p>
              ) : (
                <Loader2 className="h-4 w-4 animate-spin" />
              )}
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* 输入区域 */}
      <div className="p-4 border-t bg-background">
        <div className="flex gap-2">
          <Input
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder="输入你想说的话..."
            disabled={isStreaming}
            className="flex-1"
          />
          <Button
            onClick={handleSend}
            disabled={!inputValue.trim() || isStreaming}
          >
            {isStreaming ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Send className="h-4 w-4" />
            )}
          </Button>
        </div>
      </div>
    </div>
  )
}

// 消息气泡组件
interface MessageBubbleProps {
  message: ChatMessage
  mentorName?: string
}

function MessageBubble({ message, mentorName }: MessageBubbleProps) {
  const isUser = message.role === 'user'

  return (
    <div
      className={cn('flex items-start gap-3', isUser && 'flex-row-reverse')}
    >
      <Avatar className="h-8 w-8">
        <AvatarFallback className={isUser ? 'bg-primary text-primary-foreground' : ''}>
          {isUser ? '我' : <Sparkles className="h-4 w-4" />}
        </AvatarFallback>
      </Avatar>
      <div
        className={cn(
          'max-w-[70%] rounded-2xl px-4 py-2',
          isUser
            ? 'bg-primary text-primary-foreground rounded-tr-none'
            : 'bg-muted rounded-tl-none'
        )}
      >
        <p className="whitespace-pre-wrap">{message.content}</p>
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

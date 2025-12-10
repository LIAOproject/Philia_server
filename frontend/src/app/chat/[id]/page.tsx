'use client'

import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useParams, useRouter } from 'next/navigation'
import { ArrowLeft, Loader2, Trash2, Settings } from 'lucide-react'
import { useMutation, useQueryClient } from '@tanstack/react-query'

import { chatApi } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { ChatInterface } from '@/components/features/chat-interface'
import { ChatbotDebugPanel } from '@/components/features/chatbot-debug-panel'
import { useToast } from '@/hooks/use-toast'
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from '@/components/ui/alert-dialog'

export default function ChatPage() {
  const params = useParams()
  const router = useRouter()
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const chatbotId = params.id as string
  const [debugPanelOpen, setDebugPanelOpen] = useState(false)

  // 获取 Chatbot 详情
  const { data: chatbot, isLoading, error } = useQuery({
    queryKey: ['chatbot', chatbotId],
    queryFn: () => chatApi.getChatbot(chatbotId),
  })

  // 删除 Chatbot
  const deleteMutation = useMutation({
    mutationFn: () => chatApi.deleteChatbot(chatbotId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['chatbots'] })
      toast({
        title: '删除成功',
        description: '对话已删除',
      })
      router.push('/')
    },
    onError: (error: Error) => {
      toast({
        title: '删除失败',
        description: error.message,
        variant: 'destructive',
      })
    },
  })

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  if (error || !chatbot) {
    return (
      <div className="flex flex-col items-center justify-center min-h-screen gap-4">
        <p className="text-muted-foreground">对话不存在或已被删除</p>
        <Button onClick={() => router.push('/')}>
          <ArrowLeft className="mr-2 h-4 w-4" />
          返回首页
        </Button>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-screen">
      {/* 页面头部 */}
      <header className="flex items-center justify-between px-4 py-3 border-b bg-background/95 backdrop-blur">
        <Button variant="ghost" size="sm" onClick={() => router.back()}>
          <ArrowLeft className="mr-2 h-4 w-4" />
          返回
        </Button>
        <h1 className="font-semibold">{chatbot.title}</h1>
        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => setDebugPanelOpen(!debugPanelOpen)}
          >
            <Settings className="h-4 w-4" />
          </Button>
          <AlertDialog>
            <AlertDialogTrigger asChild>
              <Button variant="ghost" size="sm">
                <Trash2 className="h-4 w-4 text-destructive" />
              </Button>
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>确认删除</AlertDialogTitle>
                <AlertDialogDescription>
                  确定要删除这个对话吗？所有聊天记录将被永久删除。
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>取消</AlertDialogCancel>
                <AlertDialogAction
                  onClick={() => deleteMutation.mutate()}
                  className="bg-destructive text-destructive-foreground hover:bg-destructive/90"
                >
                  删除
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      </header>

      {/* 聊天界面 */}
      <div className="flex-1 overflow-hidden">
        <ChatInterface chatbot={chatbot} />
      </div>

      {/* 调试面板 */}
      <ChatbotDebugPanel
        chatbotId={chatbotId}
        isOpen={debugPanelOpen}
        onToggle={() => setDebugPanelOpen(!debugPanelOpen)}
      />
    </div>
  )
}

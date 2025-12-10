'use client'

import { useState } from 'react'
import { useParams, useRouter } from 'next/navigation'
import Link from 'next/link'
import { useQuery } from '@tanstack/react-query'
import { ArrowLeft, Loader2 } from 'lucide-react'

import { targetApi } from '@/lib/api'
import { Chatbot } from '@/types'
import { Button } from '@/components/ui/button'
import { TargetProfileCard } from '@/components/features/target-profile-card'
import { OperationPanel } from '@/components/features/operation-panel'
import { ChatDetailPanel } from '@/components/features/chat-detail-panel'

export default function TargetDetailPage() {
  const params = useParams()
  const router = useRouter()
  const targetId = params.id as string
  const [selectedChatbot, setSelectedChatbot] = useState<Chatbot | null>(null)

  // 获取对象详情
  const { data: target, isLoading: targetLoading } = useQuery({
    queryKey: ['target', targetId],
    queryFn: () => targetApi.get(targetId),
    enabled: !!targetId,
  })

  // 加载中
  if (targetLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  // 对象不存在
  if (!target) {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center">
        <p className="text-muted-foreground mb-4">对象不存在或已被删除</p>
        <Button onClick={() => router.push('/')}>返回首页</Button>
      </div>
    )
  }

  return (
    <div className="h-screen flex flex-col bg-background">
      {/* 顶部导航 */}
      <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 shrink-0">
        <div className="flex h-14 items-center px-4">
          <Link
            href="/"
            className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="h-4 w-4" />
            返回
          </Link>
          <span className="ml-4 font-medium">{target.name}</span>
        </div>
      </header>

      {/* 三栏布局主体 */}
      <main className="flex-1 flex overflow-hidden">
        {/* 左侧栏：对象报告卡片 */}
        <aside className="w-72 border-r bg-muted/30 p-4 overflow-y-auto shrink-0">
          <TargetProfileCard target={target} />
        </aside>

        {/* 中间栏：操作台 */}
        <div className="w-80 border-r p-4 shrink-0">
          <OperationPanel
            targetId={targetId}
            targetName={target.name}
            onSelectChatbot={setSelectedChatbot}
            selectedChatbotId={selectedChatbot?.id}
          />
        </div>

        {/* 右侧栏：聊天详情页 */}
        <div className="flex-1 min-w-0">
          <ChatDetailPanel chatbot={selectedChatbot} />
        </div>
      </main>
    </div>
  )
}

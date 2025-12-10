'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useRouter } from 'next/navigation'
import { Loader2 } from 'lucide-react'

import { chatApi } from '@/lib/api'
import { AIMentor } from '@/types'
import { Button } from '@/components/ui/button'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { MentorCard } from './mentor-card'
import { useToast } from '@/hooks/use-toast'

interface MentorSelectorProps {
  targetId: string
  targetName: string
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function MentorSelector({
  targetId,
  targetName,
  open,
  onOpenChange,
}: MentorSelectorProps) {
  const router = useRouter()
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [selectedMentor, setSelectedMentor] = useState<AIMentor | null>(null)

  // 获取导师列表
  const { data: mentorsData, isLoading } = useQuery({
    queryKey: ['mentors'],
    queryFn: () => chatApi.listMentors(),
    enabled: open,
  })

  // 创建 Chatbot
  const createMutation = useMutation({
    mutationFn: chatApi.createChatbot,
    onSuccess: (chatbot) => {
      queryClient.invalidateQueries({ queryKey: ['chatbots'] })
      toast({
        title: '创建成功',
        description: `已开始与 ${selectedMentor?.name} 的对话`,
      })
      onOpenChange(false)
      // 跳转到聊天页面
      router.push(`/chat/${chatbot.id}`)
    },
    onError: (error: Error) => {
      toast({
        title: '创建失败',
        description: error.message,
        variant: 'destructive',
      })
    },
  })

  const handleCreate = () => {
    if (!selectedMentor) return

    createMutation.mutate({
      target_id: targetId,
      mentor_id: selectedMentor.id,
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-3xl max-h-[80vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>选择 AI 导师</DialogTitle>
          <DialogDescription>
            为 {targetName} 选择一位 AI 情感导师，开始咨询对话
          </DialogDescription>
        </DialogHeader>

        {isLoading ? (
          <div className="flex items-center justify-center py-12">
            <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 py-4">
            {mentorsData?.items.map((mentor) => (
              <MentorCard
                key={mentor.id}
                mentor={mentor}
                selected={selectedMentor?.id === mentor.id}
                onClick={() => setSelectedMentor(mentor)}
              />
            ))}
          </div>
        )}

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            取消
          </Button>
          <Button
            onClick={handleCreate}
            disabled={!selectedMentor || createMutation.isPending}
          >
            {createMutation.isPending && (
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
            )}
            开始对话
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

'use client'

import { useState, useCallback } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { useDropzone } from 'react-dropzone'
import { format } from 'date-fns'
import { zhCN } from 'date-fns/locale'
import {
  Image as ImageIcon,
  MessageCircle,
  Plus,
  Upload,
  Loader2,
  Sparkles,
  Trash2,
} from 'lucide-react'

import { chatApi, memoryApi, uploadApi } from '@/lib/api'
import { cn, formatRelativeTime, API_BASE_URL } from '@/lib/utils'
import { Memory, Chatbot, AIMentor } from '@/types'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
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
import {
  HoverCard,
  HoverCardContent,
  HoverCardTrigger,
} from '@/components/ui/hover-card'

interface OperationPanelProps {
  targetId: string
  targetName: string
  onSelectChatbot: (chatbot: Chatbot | null) => void
  selectedChatbotId?: string | null
  className?: string
}

export function OperationPanel({
  targetId,
  targetName,
  onSelectChatbot,
  selectedChatbotId,
  className,
}: OperationPanelProps) {
  const { toast } = useToast()
  const queryClient = useQueryClient()
  const [mentorSelectorOpen, setMentorSelectorOpen] = useState(false)
  const [selectedMentor, setSelectedMentor] = useState<AIMentor | null>(null)

  // 获取记忆列表（包含图片）
  const { data: memoriesData, isLoading: memoriesLoading } = useQuery({
    queryKey: ['memories', targetId],
    queryFn: () => memoryApi.getTimeline(targetId, { limit: 100 }),
    enabled: !!targetId,
  })

  // 获取聊天列表
  const { data: chatbotsData, isLoading: chatbotsLoading } = useQuery({
    queryKey: ['chatbots', targetId],
    queryFn: () => chatApi.listChatbots({ target_id: targetId }),
    enabled: !!targetId,
  })

  // 获取导师列表
  const { data: mentorsData, isLoading: mentorsLoading } = useQuery({
    queryKey: ['mentors'],
    queryFn: () => chatApi.listMentors(),
    enabled: mentorSelectorOpen,
  })

  // 上传图片（不传 source_type，让 AI 自动识别）
  const uploadMutation = useMutation({
    mutationFn: async (file: File) => {
      return uploadApi.analyze(file, targetId)
    },
    onSuccess: (data) => {
      toast({
        title: '分析完成',
        description: `创建了 ${data.memories_created} 条记忆${data.profile_updated ? '，档案已更新' : ''}`,
        variant: 'success',
      })
      queryClient.invalidateQueries({ queryKey: ['target', targetId] })
      queryClient.invalidateQueries({ queryKey: ['memories', targetId] })
      queryClient.invalidateQueries({ queryKey: ['targets'] })
    },
    onError: (error: Error) => {
      toast({
        title: '上传失败',
        description: error.message || '请稍后重试',
        variant: 'destructive',
      })
    },
  })

  // 创建 Chatbot
  const createChatbotMutation = useMutation({
    mutationFn: chatApi.createChatbot,
    onSuccess: (chatbot) => {
      queryClient.invalidateQueries({ queryKey: ['chatbots', targetId] })
      toast({
        title: '创建成功',
        description: `已开始与 ${selectedMentor?.name} 的对话`,
      })
      setMentorSelectorOpen(false)
      setSelectedMentor(null)
      onSelectChatbot(chatbot)
    },
    onError: (error: Error) => {
      toast({
        title: '创建失败',
        description: error.message,
        variant: 'destructive',
      })
    },
  })

  // 删除 Chatbot
  const deleteChatbotMutation = useMutation({
    mutationFn: chatApi.deleteChatbot,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['chatbots', targetId] })
      toast({
        title: '删除成功',
      })
      if (selectedChatbotId) {
        onSelectChatbot(null)
      }
    },
    onError: (error: Error) => {
      toast({
        title: '删除失败',
        description: error.message,
        variant: 'destructive',
      })
    },
  })

  // 文件上传处理
  const onDrop = useCallback(
    (acceptedFiles: File[]) => {
      const file = acceptedFiles[0]
      if (!file) return
      uploadMutation.mutate(file)
    },
    [uploadMutation]
  )

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': ['.png', '.jpg', '.jpeg', '.gif', '.webp'],
    },
    maxSize: 10 * 1024 * 1024,
    multiple: false,
    disabled: uploadMutation.isPending,
  })

  // 只筛选有图片的记忆
  const memoriesWithImages = memoriesData?.items?.filter((m) => m.image_url) || []

  const handleCreateChatbot = () => {
    if (!selectedMentor) return
    createChatbotMutation.mutate({
      target_id: targetId,
      mentor_id: selectedMentor.id,
    })
  }

  return (
    <div className={cn('flex flex-col h-full', className)}>
      <Tabs defaultValue="images" className="flex-1 flex flex-col">
        <TabsList className="grid w-full grid-cols-2 shrink-0">
          <TabsTrigger value="images" className="gap-1.5">
            <ImageIcon className="h-4 w-4" />
            图片
          </TabsTrigger>
          <TabsTrigger value="chatbots" className="gap-1.5">
            <MessageCircle className="h-4 w-4" />
            对话
          </TabsTrigger>
        </TabsList>

        {/* 图片列表 Tab */}
        <TabsContent value="images" className="flex-1 relative mt-4">
          {/* 列表区域 - 从顶部开始，底部留出按钮空间 */}
          <div className="absolute inset-0 bottom-16 overflow-y-auto pr-1">
            {memoriesLoading ? (
              <div className="py-8 text-center">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground mx-auto" />
              </div>
            ) : memoriesWithImages.length > 0 ? (
              <div className="space-y-2">
                {memoriesWithImages.map((memory) => (
                  <ImageItem key={memory.id} memory={memory} />
                ))}
              </div>
            ) : (
              <div className="text-muted-foreground py-4">
                <p className="text-sm">暂无图片</p>
                <p className="text-xs mt-1">上传截图开始记录</p>
              </div>
            )}
          </div>

          {/* 上传按钮 - 固定在底部 */}
          <div className="absolute bottom-0 left-0 right-0">
            <div {...getRootProps()}>
              <input {...getInputProps()} />
              <Button
                className="w-full gap-2"
                disabled={uploadMutation.isPending}
              >
                {uploadMutation.isPending ? (
                  <>
                    <Loader2 className="h-4 w-4 animate-spin" />
                    AI 分析中...
                  </>
                ) : (
                  <>
                    <Plus className="h-4 w-4" />
                    上传图片
                  </>
                )}
              </Button>
            </div>
          </div>
        </TabsContent>

        {/* 对话列表 Tab */}
        <TabsContent value="chatbots" className="flex-1 relative mt-4">
          {/* 列表区域 - 从顶部开始，底部留出按钮空间 */}
          <div className="absolute inset-0 bottom-16 overflow-y-auto pr-1">
            {chatbotsLoading ? (
              <div className="py-8 text-center">
                <Loader2 className="h-6 w-6 animate-spin text-muted-foreground mx-auto" />
              </div>
            ) : chatbotsData?.items && chatbotsData.items.length > 0 ? (
              <div className="space-y-2">
                {chatbotsData.items.map((chatbot) => (
                  <ChatbotItem
                    key={chatbot.id}
                    chatbot={chatbot}
                    selected={selectedChatbotId === chatbot.id}
                    onClick={() => onSelectChatbot(chatbot)}
                    onDelete={() => deleteChatbotMutation.mutate(chatbot.id)}
                  />
                ))}
              </div>
            ) : (
              <div className="text-muted-foreground py-4">
                <p className="text-sm">暂无对话</p>
                <p className="text-xs mt-1">创建一个新对话开始咨询</p>
              </div>
            )}
          </div>

          {/* 新建对话按钮 - 固定在底部 */}
          <div className="absolute bottom-0 left-0 right-0">
            <Button
              className="w-full gap-2"
              onClick={() => setMentorSelectorOpen(true)}
            >
              <Plus className="h-4 w-4" />
              新建对话
            </Button>
          </div>
        </TabsContent>
      </Tabs>

      {/* 导师选择弹窗 */}
      <Dialog open={mentorSelectorOpen} onOpenChange={setMentorSelectorOpen}>
        <DialogContent className="max-w-3xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>选择 AI 导师</DialogTitle>
            <DialogDescription>
              为 {targetName} 选择一位 AI 情感导师，开始咨询对话
            </DialogDescription>
          </DialogHeader>

          {mentorsLoading ? (
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
            <Button variant="outline" onClick={() => setMentorSelectorOpen(false)}>
              取消
            </Button>
            <Button
              onClick={handleCreateChatbot}
              disabled={!selectedMentor || createChatbotMutation.isPending}
            >
              {createChatbotMutation.isPending && (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              )}
              开始对话
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}

// 图片项组件 - IM列表卡片样式，悬浮显示预览
function ImageItem({ memory }: { memory: Memory }) {
  // 构建完整的图片 URL
  const imageUrl = memory.image_url?.startsWith('http')
    ? memory.image_url
    : `${API_BASE_URL}${memory.image_url}`

  // 获取 AI 识别的图片类型（从 extracted_facts 或 source_type）
  const imageType = memory.extracted_facts?.image_type || memory.source_type || 'photo'

  return (
    <HoverCard openDelay={200} closeDelay={100}>
      <HoverCardTrigger asChild>
        {/* 列表卡片 */}
        <div className="flex items-center gap-3 p-3 rounded-lg border hover:bg-muted/50 transition-colors cursor-pointer">
          {/* 图片图标 */}
          <div className="h-10 w-10 rounded-lg bg-muted flex items-center justify-center shrink-0">
            <ImageIcon className="h-5 w-5 text-muted-foreground" />
          </div>
          {/* 信息 */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium truncate">{imageType}</span>
            </div>
            <p className="text-xs text-muted-foreground">
              {formatRelativeTime(memory.happened_at)}
            </p>
          </div>
        </div>
      </HoverCardTrigger>

      {/* 悬浮预览气泡 - 自适应图片尺寸 */}
      <HoverCardContent side="right" align="start" className="w-auto max-w-md p-3">
        {/* 图片完整预览 */}
        <img
          src={imageUrl}
          alt="预览"
          className="max-w-full max-h-[60vh] rounded-lg object-contain"
        />
        {/* 详情信息 */}
        <div className="space-y-1.5 text-sm mt-3 min-w-[200px]">
          <div className="flex justify-between gap-4">
            <span className="text-muted-foreground">类型</span>
            <span className="font-medium">{imageType}</span>
          </div>
          <div className="flex justify-between gap-4">
            <span className="text-muted-foreground">时间</span>
            <span>{formatRelativeTime(memory.happened_at)}</span>
          </div>
          {memory.extracted_facts?.sentiment && (
            <div className="flex justify-between gap-4">
              <span className="text-muted-foreground">情绪</span>
              <span>{memory.extracted_facts.sentiment}</span>
            </div>
          )}
          {memory.content && (
            <div className="pt-2 border-t">
              <p className="text-muted-foreground text-xs line-clamp-4">{memory.content}</p>
            </div>
          )}
        </div>
      </HoverCardContent>
    </HoverCard>
  )
}

// 聊天项组件
function ChatbotItem({
  chatbot,
  selected,
  onClick,
  onDelete,
}: {
  chatbot: Chatbot
  selected: boolean
  onClick: () => void
  onDelete: () => void
}) {
  return (
    <div
      className={cn(
        'group flex items-center gap-3 p-3 rounded-lg border cursor-pointer transition-colors',
        selected
          ? 'bg-primary/10 border-primary'
          : 'hover:bg-muted/50 border-transparent hover:border-border'
      )}
      onClick={onClick}
    >
      <Avatar className="h-10 w-10 shrink-0">
        {chatbot.mentor_icon_url ? (
          <AvatarImage src={chatbot.mentor_icon_url} />
        ) : null}
        <AvatarFallback>
          <Sparkles className="h-5 w-5" />
        </AvatarFallback>
      </Avatar>
      <div className="flex-1 min-w-0">
        <div className="flex items-center justify-between">
          <p className="font-medium text-sm truncate">{chatbot.mentor_name}</p>
          <span className="text-xs text-muted-foreground shrink-0">
            {formatRelativeTime(chatbot.updated_at)}
          </span>
        </div>
        <p className="text-xs text-muted-foreground truncate">
          {chatbot.message_count ? `${chatbot.message_count} 条消息` : '暂无消息'}
        </p>
      </div>
      <Button
        variant="ghost"
        size="icon"
        className="h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity shrink-0"
        onClick={(e) => {
          e.stopPropagation()
          onDelete()
        }}
      >
        <Trash2 className="h-4 w-4 text-muted-foreground hover:text-destructive" />
      </Button>
    </div>
  )
}

'use client'

import { useRouter } from 'next/navigation'
import { MessageSquare, Calendar, MoreHorizontal, Trash2 } from 'lucide-react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { cn, formatRelativeTime } from '@/lib/utils'
import { targetApi } from '@/lib/api'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent } from '@/components/ui/card'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useToast } from '@/hooks/use-toast'
import type { Target, RELATIONSHIP_STATUS_OPTIONS } from '@/types'

interface TargetCardProps {
  target: Target
}

// 状态颜色映射
const statusColorMap: Record<string, string> = {
  pursuing: 'bg-pink-500',
  dating: 'bg-red-500',
  friend: 'bg-blue-500',
  complicated: 'bg-yellow-500',
  ended: 'bg-gray-500',
}

// 状态标签映射
const statusLabelMap: Record<string, string> = {
  pursuing: '追求中',
  dating: '约会中',
  friend: '朋友',
  complicated: '复杂',
  ended: '已结束',
}

export function TargetCard({ target }: TargetCardProps) {
  const router = useRouter()
  const { toast } = useToast()
  const queryClient = useQueryClient()

  // 删除 mutation
  const deleteMutation = useMutation({
    mutationFn: () => targetApi.delete(target.id),
    onSuccess: () => {
      toast({
        title: '删除成功',
        description: `${target.name} 已被删除`,
      })
      queryClient.invalidateQueries({ queryKey: ['targets'] })
    },
    onError: () => {
      toast({
        title: '删除失败',
        description: '请稍后重试',
        variant: 'destructive',
      })
    },
  })

  // 获取头像首字母
  const getInitials = (name: string) => {
    return name.slice(0, 2).toUpperCase()
  }

  // 获取标签列表 (最多显示 4 个)
  const tags = target.profile_data?.tags?.slice(0, 4) || []

  // 处理卡片点击 - 导航到对象页面
  const handleCardClick = (e: React.MouseEvent) => {
    // 如果点击的是菜单按钮或菜单内容，不触发导航
    const target_el = e.target as HTMLElement
    if (target_el.closest('[data-radix-dropdown-menu-trigger]') ||
        target_el.closest('[role="menu"]')) {
      return
    }
    router.push(`/target/${target.id}`)
  }

  return (
    <Card
      className="group hover:shadow-md transition-shadow cursor-pointer"
      onClick={handleCardClick}
    >
      <CardContent className="p-4">
        {/* 头部：头像和状态 */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              <AvatarImage src={target.avatar_url || undefined} />
              <AvatarFallback className="bg-primary/10 text-primary">
                {getInitials(target.name)}
              </AvatarFallback>
            </Avatar>
            <div>
              <h3 className="font-semibold group-hover:text-primary transition-colors">
                {target.name}
              </h3>
              {target.current_status && (
                <Badge
                  variant="secondary"
                  className={cn(
                    'text-white text-xs',
                    statusColorMap[target.current_status] || 'bg-gray-500'
                  )}
                >
                  {statusLabelMap[target.current_status] || target.current_status}
                </Badge>
              )}
            </div>
          </div>

          {/* 操作菜单 */}
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                variant="ghost"
                size="icon"
                className="opacity-0 group-hover:opacity-100 transition-opacity"
                onClick={(e) => e.stopPropagation()}
                data-radix-dropdown-menu-trigger
              >
                <MoreHorizontal className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onClick={(e) => {
                  e.stopPropagation()
                  deleteMutation.mutate()
                }}
                disabled={deleteMutation.isPending}
              >
                <Trash2 className="mr-2 h-4 w-4" />
                删除
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>

        {/* 标签列表 */}
        {tags.length > 0 && (
          <div className="flex flex-wrap gap-1 mb-3">
            {tags.map((tag, index) => (
              <Badge key={index} variant="outline" className="text-xs">
                {tag}
              </Badge>
            ))}
            {(target.profile_data?.tags?.length || 0) > 4 && (
              <Badge variant="outline" className="text-xs">
                +{(target.profile_data?.tags?.length || 0) - 4}
              </Badge>
            )}
          </div>
        )}

        {/* 底部统计 */}
        <div className="flex items-center justify-between text-xs text-muted-foreground">
          <span className="flex items-center gap-1">
            <MessageSquare className="h-3 w-3" />
            {target.memory_count || 0} 条记忆
          </span>
          <span className="flex items-center gap-1">
            <Calendar className="h-3 w-3" />
            {formatRelativeTime(target.updated_at)}
          </span>
        </div>
      </CardContent>
    </Card>
  )
}

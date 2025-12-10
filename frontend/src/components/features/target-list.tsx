'use client'

import { useQuery } from '@tanstack/react-query'
import { Users, Loader2 } from 'lucide-react'
import { targetApi } from '@/lib/api'
import { TargetCard } from './target-card'

export function TargetList() {
  const { data, isLoading, error } = useQuery({
    queryKey: ['targets'],
    queryFn: () => targetApi.list({ limit: 50 }),
  })

  // 加载状态
  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    )
  }

  // 错误状态
  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-destructive">加载失败，请刷新重试</p>
      </div>
    )
  }

  // 空状态
  if (!data?.items?.length) {
    return (
      <div className="text-center py-12">
        <Users className="h-12 w-12 mx-auto text-muted-foreground/50" />
        <h3 className="mt-4 text-lg font-medium">还没有添加任何对象</h3>
        <p className="mt-1 text-muted-foreground">
          点击右上角的「添加对象」开始吧
        </p>
      </div>
    )
  }

  return (
    <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
      {data.items.map((target) => (
        <TargetCard key={target.id} target={target} />
      ))}
    </div>
  )
}

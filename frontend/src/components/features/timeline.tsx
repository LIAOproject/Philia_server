'use client'

import { useState } from 'react'
import Image from 'next/image'
import {
  MessageSquare,
  AlertTriangle,
  ThumbsUp,
  ChevronDown,
  ChevronUp,
} from 'lucide-react'
import { cn, formatDate, formatRelativeTime, getSentimentColor, getSentimentEmoji } from '@/lib/utils'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { API_BASE_URL } from '@/lib/utils'
import type { Memory } from '@/types'

interface TimelineProps {
  memories: Memory[]
}

// 来源图标映射
const sourceIconMap: Record<string, string> = {
  wechat: '💬',
  qq: '🐧',
  tantan: '💕',
  soul: '👻',
  xiaohongshu: '📕',
  photo: '📷',
  manual: '✍️',
}

function TimelineItem({ memory }: { memory: Memory }) {
  const [expanded, setExpanded] = useState(false)

  const facts = memory.extracted_facts || {}
  const hasDetails =
    facts.subtext ||
    (facts.red_flags?.length ?? 0) > 0 ||
    (facts.green_flags?.length ?? 0) > 0 ||
    (facts.topics?.length ?? 0) > 0

  return (
    <div className="relative pl-8 pb-8 last:pb-0">
      {/* 时间轴线 */}
      <div className="absolute left-3 top-2 bottom-0 w-px bg-border last:hidden" />

      {/* 时间轴点 */}
      <div
        className={cn(
          'absolute left-0 top-2 w-6 h-6 rounded-full flex items-center justify-center text-xs',
          memory.sentiment_score >= 3
            ? 'bg-green-100 text-green-600'
            : memory.sentiment_score <= -3
            ? 'bg-red-100 text-red-600'
            : 'bg-gray-100 text-gray-600'
        )}
      >
        {getSentimentEmoji(memory.sentiment_score)}
      </div>

      {/* 内容 */}
      <div className="bg-muted/30 rounded-lg p-4">
        {/* 头部：时间和来源 */}
        <div className="flex items-center justify-between mb-2">
          <div className="flex items-center gap-2 text-xs text-muted-foreground">
            <span>{sourceIconMap[memory.source_type] || '📝'}</span>
            <span>{formatDate(memory.happened_at)}</span>
            <span className="text-muted-foreground/50">·</span>
            <span>{formatRelativeTime(memory.happened_at)}</span>
          </div>
          <div className="flex items-center gap-2">
            <span className={cn('text-sm font-medium', getSentimentColor(memory.sentiment_score))}>
              {facts.sentiment || '中性'}
            </span>
            <span className={cn(
              'text-xs px-1.5 py-0.5 rounded',
              memory.sentiment_score > 0 ? 'bg-green-100 text-green-700' :
              memory.sentiment_score < 0 ? 'bg-red-100 text-red-700' :
              'bg-gray-100 text-gray-600'
            )}>
              {memory.sentiment_score > 0 ? '+' : ''}{memory.sentiment_score}
            </span>
          </div>
        </div>

        {/* 内容摘要 */}
        {memory.content && (
          <p className="text-sm mb-3">{memory.content}</p>
        )}

        {/* 图片预览 */}
        {memory.image_url && (
          <div className="mb-3">
            <Image
              src={`${API_BASE_URL}${memory.image_url}`}
              alt="截图"
              width={200}
              height={150}
              className="rounded-lg object-cover cursor-pointer hover:opacity-90 transition-opacity"
              onClick={() => window.open(`${API_BASE_URL}${memory.image_url}`, '_blank')}
            />
          </div>
        )}

        {/* 关键事件 */}
        {facts.key_event && (
          <Badge variant="outline" className="mb-2">
            {facts.key_event}
          </Badge>
        )}

        {/* 展开详情 */}
        {hasDetails && (
          <>
            <Button
              variant="ghost"
              size="sm"
              className="w-full mt-2"
              onClick={() => setExpanded(!expanded)}
            >
              {expanded ? (
                <>
                  <ChevronUp className="h-4 w-4 mr-1" />
                  收起
                </>
              ) : (
                <>
                  <ChevronDown className="h-4 w-4 mr-1" />
                  查看详情
                </>
              )}
            </Button>

            {expanded && (
              <div className="mt-3 pt-3 border-t space-y-3 animate-fade-in">
                {/* 潜台词分析 */}
                {facts.subtext && (
                  <div>
                    <p className="text-xs text-muted-foreground mb-1 flex items-center gap-1">
                      <MessageSquare className="h-3 w-3" />
                      潜台词分析
                    </p>
                    <p className="text-sm bg-background p-2 rounded">
                      {facts.subtext}
                    </p>
                  </div>
                )}

                {/* 话题 */}
                {facts.topics && facts.topics.length > 0 && (
                  <div>
                    <p className="text-xs text-muted-foreground mb-1">讨论话题</p>
                    <div className="flex flex-wrap gap-1">
                      {facts.topics.map((topic, index) => (
                        <Badge key={index} variant="secondary" className="text-xs">
                          {topic}
                        </Badge>
                      ))}
                    </div>
                  </div>
                )}

                {/* Red Flags */}
                {facts.red_flags && facts.red_flags.length > 0 && (
                  <div>
                    <p className="text-xs text-destructive mb-1 flex items-center gap-1">
                      <AlertTriangle className="h-3 w-3" />
                      危险信号
                    </p>
                    <ul className="text-sm text-destructive/80 space-y-1">
                      {facts.red_flags.map((flag, index) => (
                        <li key={index} className="flex items-start gap-1">
                          <span>•</span>
                          <span>{flag}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {/* Green Flags */}
                {facts.green_flags && facts.green_flags.length > 0 && (
                  <div>
                    <p className="text-xs text-green-600 mb-1 flex items-center gap-1">
                      <ThumbsUp className="h-3 w-3" />
                      积极信号
                    </p>
                    <ul className="text-sm text-green-600/80 space-y-1">
                      {facts.green_flags.map((flag, index) => (
                        <li key={index} className="flex items-start gap-1">
                          <span>•</span>
                          <span>{flag}</span>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </div>
            )}
          </>
        )}
      </div>
    </div>
  )
}

export function Timeline({ memories }: TimelineProps) {
  if (!memories.length) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        暂无互动记录
      </div>
    )
  }

  return (
    <div className="relative">
      {memories.map((memory) => (
        <TimelineItem key={memory.id} memory={memory} />
      ))}
    </div>
  )
}

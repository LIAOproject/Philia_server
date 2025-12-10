'use client'

import { useState } from 'react'
import {
  Calendar,
  MapPin,
  Briefcase,
  Sparkles,
  GraduationCap,
  User,
  Brain,
  Eye,
  Settings,
  Database,
  Copy,
  Check,
} from 'lucide-react'
import { Target } from '@/types'
import { cn, formatDate } from '@/lib/utils'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'

// 状态标签映射
const statusLabelMap: Record<string, string> = {
  pursuing: '追求中',
  dating: '约会中',
  friend: '朋友',
  complicated: '复杂',
  ended: '已结束',
}

interface TargetProfileCardProps {
  target: Target
  className?: string
}

export function TargetProfileCard({ target, className }: TargetProfileCardProps) {
  const [copied, setCopied] = useState(false)

  // 获取头像首字母
  const getInitials = (name: string) => name.slice(0, 2).toUpperCase()

  // 复制 JSON 到剪贴板
  const copyToClipboard = (data: unknown) => {
    navigator.clipboard.writeText(JSON.stringify(data, null, 2))
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <div className={cn('space-y-4 overflow-y-auto', className)}>
      {/* 基础信息卡片 */}
      <Card>
        <CardContent className="pt-6">
          {/* 设置按钮 - 右上角 */}
          <div className="flex justify-end -mt-2 -mr-2 mb-2">
            <Dialog>
              <DialogTrigger asChild>
                <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                  <Settings className="h-4 w-4" />
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-2xl max-h-[85vh] overflow-hidden flex flex-col">
                <DialogHeader>
                  <DialogTitle className="flex items-center gap-2">
                    <Database className="h-5 w-5" />
                    {target.name} - 数据详情
                  </DialogTitle>
                  <DialogDescription>
                    查看此对象的所有存储数据
                  </DialogDescription>
                </DialogHeader>
                <Tabs defaultValue="overview" className="flex-1 overflow-hidden flex flex-col">
                  <TabsList className="grid w-full grid-cols-4">
                    <TabsTrigger value="overview">概览</TabsTrigger>
                    <TabsTrigger value="profile">档案</TabsTrigger>
                    <TabsTrigger value="preferences">喜好</TabsTrigger>
                    <TabsTrigger value="raw">原始 JSON</TabsTrigger>
                  </TabsList>

                  {/* 概览 */}
                  <TabsContent value="overview" className="flex-1 overflow-y-auto mt-4 space-y-4">
                    <div className="grid grid-cols-2 gap-4">
                      <InfoItem label="ID" value={target.id} mono />
                      <InfoItem label="名称" value={target.name} />
                      <InfoItem label="状态" value={statusLabelMap[target.current_status || ''] || target.current_status || '未设置'} />
                      <InfoItem label="创建时间" value={formatDate(target.created_at)} />
                      <InfoItem label="更新时间" value={formatDate(target.updated_at)} />
                    </div>
                    {target.ai_summary && (
                      <div className="space-y-1">
                        <p className="text-xs font-medium text-muted-foreground">AI 摘要</p>
                        <p className="text-sm bg-muted/50 rounded-md p-3 whitespace-pre-wrap">
                          {target.ai_summary}
                        </p>
                      </div>
                    )}
                  </TabsContent>

                  {/* 档案数据 */}
                  <TabsContent value="profile" className="flex-1 overflow-y-auto mt-4 space-y-4">
                    {target.profile_data ? (
                      <>
                        <div className="grid grid-cols-2 gap-4">
                          <InfoItem label="年龄范围" value={target.profile_data.age_range} />
                          <InfoItem label="星座" value={target.profile_data.zodiac} />
                          <InfoItem label="MBTI" value={target.profile_data.mbti} />
                          <InfoItem label="所在地" value={target.profile_data.location} />
                          <InfoItem label="职业" value={target.profile_data.occupation} />
                          <InfoItem label="学历" value={target.profile_data.education} />
                        </div>
                        {target.profile_data.tags && target.profile_data.tags.length > 0 && (
                          <div className="space-y-1">
                            <p className="text-xs font-medium text-muted-foreground">标签</p>
                            <div className="flex flex-wrap gap-1">
                              {target.profile_data.tags.map((tag, i) => (
                                <Badge key={i} variant="secondary" className="text-xs">{tag}</Badge>
                              ))}
                            </div>
                          </div>
                        )}
                        {target.profile_data.appearance && Object.keys(target.profile_data.appearance).length > 0 && (
                          <div className="space-y-1">
                            <p className="text-xs font-medium text-muted-foreground">外貌特征</p>
                            <div className="bg-muted/50 rounded-md p-3 space-y-1">
                              {Object.entries(target.profile_data.appearance).map(([k, v]) => (
                                <div key={k} className="flex justify-between text-xs">
                                  <span className="text-muted-foreground">{k}</span>
                                  <span>{v}</span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                        {target.profile_data.personality && Object.keys(target.profile_data.personality).length > 0 && (
                          <div className="space-y-1">
                            <p className="text-xs font-medium text-muted-foreground">性格特征</p>
                            <div className="bg-muted/50 rounded-md p-3 space-y-1">
                              {Object.entries(target.profile_data.personality).map(([k, v]) => (
                                <div key={k} className="flex justify-between text-xs">
                                  <span className="text-muted-foreground">{k}</span>
                                  <span>{v}</span>
                                </div>
                              ))}
                            </div>
                          </div>
                        )}
                      </>
                    ) : (
                      <p className="text-sm text-muted-foreground text-center py-8">暂无档案数据</p>
                    )}
                  </TabsContent>

                  {/* 喜好数据 */}
                  <TabsContent value="preferences" className="flex-1 overflow-y-auto mt-4 space-y-4">
                    {target.preferences ? (
                      <>
                        {target.preferences.likes && target.preferences.likes.length > 0 && (
                          <div className="space-y-1">
                            <p className="text-xs font-medium text-muted-foreground">喜欢</p>
                            <div className="flex flex-wrap gap-1">
                              {target.preferences.likes.map((item, i) => (
                                <Badge key={i} variant="outline" className="text-xs bg-green-50 text-green-700 border-green-200">{item}</Badge>
                              ))}
                            </div>
                          </div>
                        )}
                        {target.preferences.dislikes && target.preferences.dislikes.length > 0 && (
                          <div className="space-y-1">
                            <p className="text-xs font-medium text-muted-foreground">不喜欢</p>
                            <div className="flex flex-wrap gap-1">
                              {target.preferences.dislikes.map((item, i) => (
                                <Badge key={i} variant="outline" className="text-xs bg-red-50 text-red-700 border-red-200">{item}</Badge>
                              ))}
                            </div>
                          </div>
                        )}
                        {(!target.preferences.likes || target.preferences.likes.length === 0) &&
                         (!target.preferences.dislikes || target.preferences.dislikes.length === 0) && (
                          <p className="text-sm text-muted-foreground text-center py-8">暂无喜好数据</p>
                        )}
                      </>
                    ) : (
                      <p className="text-sm text-muted-foreground text-center py-8">暂无喜好数据</p>
                    )}
                  </TabsContent>

                  {/* 原始 JSON */}
                  <TabsContent value="raw" className="flex-1 overflow-hidden mt-4 flex flex-col">
                    <div className="flex justify-end mb-2">
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() => copyToClipboard(target)}
                      >
                        {copied ? (
                          <>
                            <Check className="h-4 w-4 mr-1" />
                            已复制
                          </>
                        ) : (
                          <>
                            <Copy className="h-4 w-4 mr-1" />
                            复制 JSON
                          </>
                        )}
                      </Button>
                    </div>
                    <div className="flex-1 overflow-auto">
                      <pre className="text-xs font-mono bg-muted/50 rounded-md p-3 whitespace-pre-wrap break-all">
                        {JSON.stringify(target, null, 2)}
                      </pre>
                    </div>
                  </TabsContent>
                </Tabs>
              </DialogContent>
            </Dialog>
          </div>

          <div className="flex flex-col items-center text-center">
            <Avatar className="h-20 w-20 mb-3">
              <AvatarImage src={target.avatar_url || undefined} />
              <AvatarFallback className="text-xl bg-primary/10 text-primary">
                {getInitials(target.name)}
              </AvatarFallback>
            </Avatar>

            <h1 className="text-xl font-bold">{target.name}</h1>

            {target.current_status && (
              <Badge className="mt-2">
                {statusLabelMap[target.current_status] || target.current_status}
              </Badge>
            )}

            {/* 基础信息 */}
            <div className="w-full mt-4 space-y-2 text-left">
              {/* 年龄范围 */}
              {target.profile_data?.age_range && (
                <div className="flex items-center gap-2 text-sm">
                  <User className="h-4 w-4 text-muted-foreground" />
                  <span>{target.profile_data.age_range} 岁</span>
                </div>
              )}
              {/* 星座 & MBTI */}
              {(target.profile_data?.zodiac || target.profile_data?.mbti) && (
                <div className="flex items-center gap-2 text-sm">
                  <Sparkles className="h-4 w-4 text-muted-foreground" />
                  {target.profile_data.zodiac && (
                    <span>{target.profile_data.zodiac}</span>
                  )}
                  {target.profile_data.mbti && (
                    <Badge variant="outline">{target.profile_data.mbti}</Badge>
                  )}
                </div>
              )}
              {/* 所在地 */}
              {target.profile_data?.location && (
                <div className="flex items-center gap-2 text-sm">
                  <MapPin className="h-4 w-4 text-muted-foreground" />
                  <span>{target.profile_data.location}</span>
                </div>
              )}
              {/* 职业 */}
              {target.profile_data?.occupation && (
                <div className="flex items-center gap-2 text-sm">
                  <Briefcase className="h-4 w-4 text-muted-foreground" />
                  <span>{target.profile_data.occupation}</span>
                </div>
              )}
              {/* 学历 */}
              {target.profile_data?.education && (
                <div className="flex items-center gap-2 text-sm">
                  <GraduationCap className="h-4 w-4 text-muted-foreground" />
                  <span>{target.profile_data.education}</span>
                </div>
              )}
              {/* 创建时间 */}
              <div className="flex items-center gap-2 text-sm">
                <Calendar className="h-4 w-4 text-muted-foreground" />
                <span>创建于 {formatDate(target.created_at)}</span>
              </div>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 标签卡片 */}
      {target.profile_data?.tags && target.profile_data.tags.length > 0 && (
        <Card>
          <CardHeader className="pb-2 pt-4">
            <CardTitle className="text-sm">特征标签</CardTitle>
          </CardHeader>
          <CardContent className="pb-4">
            <div className="flex flex-wrap gap-1.5">
              {target.profile_data.tags.map((tag, index) => (
                <Badge key={index} variant="secondary" className="text-xs">
                  {tag}
                </Badge>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* 外貌特征卡片 */}
      {target.profile_data?.appearance && Object.keys(target.profile_data.appearance).length > 0 && (
        <Card>
          <CardHeader className="pb-2 pt-4">
            <CardTitle className="text-sm flex items-center gap-2">
              <Eye className="h-4 w-4" />
              外貌特征
            </CardTitle>
          </CardHeader>
          <CardContent className="pb-4">
            <div className="space-y-1.5">
              {Object.entries(target.profile_data.appearance).map(([key, value]) => (
                <div key={key} className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">{key}</span>
                  <span>{value}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* 性格特征卡片 */}
      {target.profile_data?.personality && Object.keys(target.profile_data.personality).length > 0 && (
        <Card>
          <CardHeader className="pb-2 pt-4">
            <CardTitle className="text-sm flex items-center gap-2">
              <Brain className="h-4 w-4" />
              性格特征
            </CardTitle>
          </CardHeader>
          <CardContent className="pb-4">
            <div className="space-y-1.5">
              {Object.entries(target.profile_data.personality).map(([key, value]) => (
                <div key={key} className="flex items-center justify-between text-xs">
                  <span className="text-muted-foreground">{key}</span>
                  <span>{value}</span>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      )}

      {/* 喜好卡片 */}
      {(target.preferences?.likes?.length > 0 ||
        target.preferences?.dislikes?.length > 0) && (
        <Card>
          <CardHeader className="pb-2 pt-4">
            <CardTitle className="text-sm">喜好</CardTitle>
          </CardHeader>
          <CardContent className="pb-4 space-y-3">
            {target.preferences?.likes?.length > 0 && (
              <div>
                <p className="text-xs text-muted-foreground mb-1.5">喜欢</p>
                <div className="flex flex-wrap gap-1.5">
                  {target.preferences.likes.map((item, index) => (
                    <Badge key={index} variant="success" className="text-xs">
                      {item}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
            {target.preferences?.dislikes?.length > 0 && (
              <div>
                <p className="text-xs text-muted-foreground mb-1.5">不喜欢</p>
                <div className="flex flex-wrap gap-1.5">
                  {target.preferences.dislikes.map((item, index) => (
                    <Badge key={index} variant="destructive" className="text-xs">
                      {item}
                    </Badge>
                  ))}
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {/* AI 摘要 */}
      {target.ai_summary && (
        <Card>
          <CardHeader className="pb-2 pt-4">
            <CardTitle className="text-sm flex items-center gap-2">
              <Sparkles className="h-4 w-4" />
              AI 分析摘要
            </CardTitle>
          </CardHeader>
          <CardContent className="pb-4">
            <p className="text-xs text-muted-foreground whitespace-pre-wrap">
              {target.ai_summary}
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  )
}

// 辅助组件：信息项
function InfoItem({ label, value, mono }: { label: string; value?: string | null; mono?: boolean }) {
  return (
    <div className="space-y-1">
      <p className="text-xs font-medium text-muted-foreground">{label}</p>
      <p className={cn('text-sm', mono && 'font-mono text-xs', !value && 'text-muted-foreground')}>
        {value || '-'}
      </p>
    </div>
  )
}

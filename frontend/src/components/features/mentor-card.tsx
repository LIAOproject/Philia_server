'use client'

import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Settings, Loader2, Plus, Trash2, Info } from 'lucide-react'
import { AIMentor, MENTOR_STYLE_OPTIONS, RAGSettings } from '@/types'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { Label } from '@/components/ui/label'
import { Input } from '@/components/ui/input'
import { Switch } from '@/components/ui/switch'
import { Slider } from '@/components/ui/slider'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from '@/components/ui/tabs'
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '@/components/ui/tooltip'
import { cn } from '@/lib/utils'
import { chatApi } from '@/lib/api'
import { useToast } from '@/hooks/use-toast'

// 默认 RAG 配置
const DEFAULT_RAG_SETTINGS: RAGSettings = {
  enabled: true,
  max_memories: 5,
  max_recent_messages: 10,
  time_decay_factor: 0.1,
  min_relevance_score: 0.0,
}

interface MentorCardProps {
  mentor: AIMentor
  selected?: boolean
  onClick?: () => void
}

export function MentorCard({ mentor, selected, onClick }: MentorCardProps) {
  const { toast } = useToast()
  const queryClient = useQueryClient()
  const [settingsOpen, setSettingsOpen] = useState(false)
  const [systemPrompt, setSystemPrompt] = useState(mentor.system_prompt_template)
  const [ragCorpus, setRagCorpus] = useState<string[]>([])
  const [ragSettings, setRagSettings] = useState<RAGSettings>(DEFAULT_RAG_SETTINGS)

  // 获取风格对应的 emoji
  const styleOption = MENTOR_STYLE_OPTIONS.find(
    (opt) => opt.value === mentor.style_tag
  )
  const emoji = styleOption?.emoji || '🤖'

  // 更新导师
  const updateMentorMutation = useMutation({
    mutationFn: (payload: { system_prompt_template?: string }) =>
      chatApi.updateMentor(mentor.id, payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mentors'] })
      toast({
        title: '保存成功',
        description: '导师设置已更新',
      })
      setSettingsOpen(false)
    },
    onError: (error: Error) => {
      toast({
        title: '保存失败',
        description: error.message,
        variant: 'destructive',
      })
    },
  })

  const handleOpenSettings = (e: React.MouseEvent) => {
    e.stopPropagation()
    setSystemPrompt(mentor.system_prompt_template)
    setRagSettings(DEFAULT_RAG_SETTINGS)
    setRagCorpus([])
    setSettingsOpen(true)
  }

  // 更新单个 RAG 配置项
  const updateRagSetting = <K extends keyof RAGSettings>(
    key: K,
    value: RAGSettings[K]
  ) => {
    setRagSettings((prev) => ({ ...prev, [key]: value }))
  }

  const handleSave = () => {
    updateMentorMutation.mutate({
      system_prompt_template: systemPrompt,
    })
  }

  const handleAddCorpusItem = () => {
    setRagCorpus([...ragCorpus, ''])
  }

  const handleRemoveCorpusItem = (index: number) => {
    setRagCorpus(ragCorpus.filter((_, i) => i !== index))
  }

  const handleCorpusChange = (index: number, value: string) => {
    const newCorpus = [...ragCorpus]
    newCorpus[index] = value
    setRagCorpus(newCorpus)
  }

  return (
    <>
      <Card
        className={cn(
          'cursor-pointer transition-all hover:shadow-md relative group',
          selected && 'ring-2 ring-primary border-primary'
        )}
        onClick={onClick}
      >
        {/* 设置按钮 */}
        <Button
          variant="ghost"
          size="icon"
          className="absolute top-2 right-2 h-8 w-8 opacity-0 group-hover:opacity-100 transition-opacity z-10"
          onClick={handleOpenSettings}
        >
          <Settings className="h-4 w-4" />
        </Button>

        <CardHeader className="pb-3">
          <div className="flex items-center gap-3">
            <Avatar className="h-12 w-12">
              {mentor.icon_url ? (
                <AvatarImage src={mentor.icon_url} alt={mentor.name} />
              ) : null}
              <AvatarFallback className="text-2xl">{emoji}</AvatarFallback>
            </Avatar>
            <div className="flex-1">
              <CardTitle className="text-lg">{mentor.name}</CardTitle>
              {mentor.style_tag && (
                <Badge variant="secondary" className="mt-1">
                  {mentor.style_tag}
                </Badge>
              )}
            </div>
          </div>
        </CardHeader>
        <CardContent>
          <CardDescription className="line-clamp-3">
            {mentor.description}
          </CardDescription>
        </CardContent>
      </Card>

      {/* 设置弹窗 */}
      <Dialog open={settingsOpen} onOpenChange={setSettingsOpen}>
        <DialogContent className="max-w-3xl max-h-[85vh] overflow-hidden flex flex-col">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2">
              <span className="text-2xl">{emoji}</span>
              {mentor.name} - 设置
            </DialogTitle>
            <DialogDescription>
              编辑导师的系统提示词和知识库语料
            </DialogDescription>
          </DialogHeader>

          <Tabs defaultValue="prompt" className="flex-1 flex flex-col overflow-hidden">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="prompt">系统提示词</TabsTrigger>
              <TabsTrigger value="rag-config">RAG 配置</TabsTrigger>
              <TabsTrigger value="corpus">RAG 语料库</TabsTrigger>
            </TabsList>

            {/* 提示词 Tab */}
            <TabsContent value="prompt" className="flex-1 flex flex-col mt-4 overflow-hidden">
              <div className="flex-1 overflow-y-auto space-y-4">
                <div className="space-y-2">
                  <Label>System Prompt 模板</Label>
                  <p className="text-xs text-muted-foreground">
                    支持占位符: {'{target_name}'}, {'{profile_summary}'}, {'{preferences}'}, {'{context}'}
                  </p>
                  <Textarea
                    value={systemPrompt}
                    onChange={(e) => setSystemPrompt(e.target.value)}
                    className="min-h-[400px] font-mono text-sm"
                    placeholder="输入系统提示词..."
                  />
                </div>
              </div>
            </TabsContent>

            {/* RAG 配置 Tab */}
            <TabsContent value="rag-config" className="flex-1 flex flex-col mt-4 overflow-hidden">
              <TooltipProvider>
                <div className="flex-1 overflow-y-auto space-y-6">
                  {/* 启用 RAG */}
                  <div className="flex items-center justify-between">
                    <div className="space-y-0.5">
                      <div className="flex items-center gap-2">
                        <Label>启用 RAG 检索</Label>
                        <Tooltip>
                          <TooltipTrigger>
                            <Info className="h-4 w-4 text-muted-foreground" />
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="max-w-xs">开启后，系统会根据用户消息检索相关记忆，注入到对话上下文中</p>
                          </TooltipContent>
                        </Tooltip>
                      </div>
                      <p className="text-xs text-muted-foreground">
                        根据用户消息检索相关记忆
                      </p>
                    </div>
                    <Switch
                      checked={ragSettings.enabled}
                      onCheckedChange={(checked) => updateRagSetting('enabled', checked)}
                    />
                  </div>

                  {/* 最大记忆数 */}
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Label>最大记忆数</Label>
                        <Tooltip>
                          <TooltipTrigger>
                            <Info className="h-4 w-4 text-muted-foreground" />
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="max-w-xs">每次对话最多检索多少条相关记忆，数值越大上下文越丰富但 token 消耗越多</p>
                          </TooltipContent>
                        </Tooltip>
                      </div>
                      <span className="text-sm font-medium">{ragSettings.max_memories}</span>
                    </div>
                    <Slider
                      value={[ragSettings.max_memories]}
                      onValueChange={([value]) => updateRagSetting('max_memories', value)}
                      min={0}
                      max={20}
                      step={1}
                      disabled={!ragSettings.enabled}
                    />
                    <p className="text-xs text-muted-foreground">
                      建议值: 3-10，设为 0 则不检索记忆
                    </p>
                  </div>

                  {/* 最大历史消息数 */}
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Label>最大历史消息数</Label>
                        <Tooltip>
                          <TooltipTrigger>
                            <Info className="h-4 w-4 text-muted-foreground" />
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="max-w-xs">包含在对话上下文中的历史消息条数，影响 AI 对对话连贯性的理解</p>
                          </TooltipContent>
                        </Tooltip>
                      </div>
                      <span className="text-sm font-medium">{ragSettings.max_recent_messages}</span>
                    </div>
                    <Slider
                      value={[ragSettings.max_recent_messages]}
                      onValueChange={([value]) => updateRagSetting('max_recent_messages', value)}
                      min={0}
                      max={50}
                      step={1}
                    />
                    <p className="text-xs text-muted-foreground">
                      建议值: 5-20，数值越大对话连贯性越好
                    </p>
                  </div>

                  {/* 时间衰减因子 */}
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Label>时间衰减因子</Label>
                        <Tooltip>
                          <TooltipTrigger>
                            <Info className="h-4 w-4 text-muted-foreground" />
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="max-w-xs">控制新旧记忆的权重比例。值越大，越偏好检索近期的记忆</p>
                          </TooltipContent>
                        </Tooltip>
                      </div>
                      <span className="text-sm font-medium">{ragSettings.time_decay_factor.toFixed(2)}</span>
                    </div>
                    <Slider
                      value={[ragSettings.time_decay_factor * 100]}
                      onValueChange={([value]) => updateRagSetting('time_decay_factor', value / 100)}
                      min={0}
                      max={100}
                      step={5}
                      disabled={!ragSettings.enabled}
                    />
                    <p className="text-xs text-muted-foreground">
                      0 = 不考虑时间，1 = 强烈偏好新记忆
                    </p>
                  </div>

                  {/* 最小相关性分数 */}
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <Label>最小相关性分数</Label>
                        <Tooltip>
                          <TooltipTrigger>
                            <Info className="h-4 w-4 text-muted-foreground" />
                          </TooltipTrigger>
                          <TooltipContent>
                            <p className="max-w-xs">只有相关性分数高于此阈值的记忆才会被检索，可过滤无关内容</p>
                          </TooltipContent>
                        </Tooltip>
                      </div>
                      <span className="text-sm font-medium">{ragSettings.min_relevance_score.toFixed(2)}</span>
                    </div>
                    <Slider
                      value={[ragSettings.min_relevance_score * 100]}
                      onValueChange={([value]) => updateRagSetting('min_relevance_score', value / 100)}
                      min={0}
                      max={100}
                      step={5}
                      disabled={!ragSettings.enabled}
                    />
                    <p className="text-xs text-muted-foreground">
                      0 = 不过滤，建议保持较低值避免漏检
                    </p>
                  </div>

                  <div className="pt-4 border-t">
                    <p className="text-xs text-muted-foreground">
                      <strong>提示：</strong>这些配置会作为使用该导师创建新 Chatbot 时的默认值。
                      每个 Chatbot 会话可以在调试面板中单独调整。
                    </p>
                  </div>
                </div>
              </TooltipProvider>
            </TabsContent>

            {/* RAG 语料库 Tab */}
            <TabsContent value="corpus" className="flex-1 flex flex-col mt-4 overflow-hidden">
              <div className="flex-1 overflow-y-auto space-y-4">
                <div className="space-y-2">
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>自定义知识库</Label>
                      <p className="text-xs text-muted-foreground mt-1">
                        添加额外的知识条目，将在 RAG 检索时被引用
                      </p>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={handleAddCorpusItem}
                      className="gap-1"
                    >
                      <Plus className="h-4 w-4" />
                      添加条目
                    </Button>
                  </div>

                  {ragCorpus.length === 0 ? (
                    <div className="text-center py-8 text-muted-foreground">
                      <p>暂无自定义语料</p>
                      <p className="text-xs mt-1">点击上方按钮添加知识条目</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {ragCorpus.map((item, index) => (
                        <div key={index} className="flex gap-2">
                          <Textarea
                            value={item}
                            onChange={(e) => handleCorpusChange(index, e.target.value)}
                            placeholder={`知识条目 ${index + 1}...`}
                            className="min-h-[80px]"
                          />
                          <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => handleRemoveCorpusItem(index)}
                            className="shrink-0"
                          >
                            <Trash2 className="h-4 w-4 text-muted-foreground hover:text-destructive" />
                          </Button>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                <div className="pt-4 border-t">
                  <p className="text-xs text-muted-foreground">
                    <strong>注意：</strong>RAG 语料库是针对每个 Chatbot 会话单独设置的，
                    这里的设置会作为该导师创建新会话时的默认配置。
                    如需修改现有会话的 RAG 设置，请在会话的调试面板中操作。
                  </p>
                </div>
              </div>
            </TabsContent>
          </Tabs>

          <DialogFooter className="mt-4">
            <Button variant="outline" onClick={() => setSettingsOpen(false)}>
              取消
            </Button>
            <Button
              onClick={handleSave}
              disabled={updateMentorMutation.isPending}
            >
              {updateMentorMutation.isPending && (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              )}
              保存
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </>
  )
}

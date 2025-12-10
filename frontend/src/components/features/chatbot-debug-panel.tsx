'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Settings,
  Code,
  Database,
  Save,
  RotateCcw,
  ChevronDown,
  ChevronUp,
  Plus,
  Trash2,
  Loader2,
  Eye,
  EyeOff,
} from 'lucide-react'

import { chatApi } from '@/lib/api'
import { ChatbotDebugSettings, RAGSettings, RAGCorpusItem } from '@/types'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { Switch } from '@/components/ui/switch'
import { Slider } from '@/components/ui/slider'
import { Badge } from '@/components/ui/badge'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { useToast } from '@/hooks/use-toast'
import { cn } from '@/lib/utils'

interface ChatbotDebugPanelProps {
  chatbotId: string
  isOpen: boolean
  onToggle: () => void
}

export function ChatbotDebugPanel({
  chatbotId,
  isOpen,
  onToggle,
}: ChatbotDebugPanelProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()

  // 本地编辑状态
  const [customPrompt, setCustomPrompt] = useState<string>('')
  const [ragSettings, setRagSettings] = useState<RAGSettings>({
    enabled: true,
    max_memories: 5,
    max_recent_messages: 10,
    time_decay_factor: 0.1,
    min_relevance_score: 0.0,
  })
  const [ragCorpus, setRagCorpus] = useState<RAGCorpusItem[]>([])
  const [showEffectivePrompt, setShowEffectivePrompt] = useState(false)
  const [isInitialized, setIsInitialized] = useState(false)

  // 获取调试设置
  const { data: debugSettings, isLoading } = useQuery({
    queryKey: ['chatbot-debug', chatbotId],
    queryFn: () => chatApi.getDebugSettings(chatbotId),
    enabled: isOpen,
  })

  // 初始化本地状态
  if (debugSettings && !isInitialized) {
    setCustomPrompt(debugSettings.custom_system_prompt || '')
    setRagSettings(debugSettings.rag_settings)
    setRagCorpus(debugSettings.rag_corpus || [])
    setIsInitialized(true)
  }

  // 更新调试设置
  const updateMutation = useMutation({
    mutationFn: (data: Parameters<typeof chatApi.updateDebugSettings>[1]) =>
      chatApi.updateDebugSettings(chatbotId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['chatbot-debug', chatbotId] })
      toast({
        title: '保存成功',
        description: '调试设置已更新',
      })
    },
    onError: (error: Error) => {
      toast({
        title: '保存失败',
        description: error.message,
        variant: 'destructive',
      })
    },
  })

  // 保存所有设置
  const handleSave = () => {
    updateMutation.mutate({
      custom_system_prompt: customPrompt,
      rag_settings: ragSettings,
      rag_corpus: ragCorpus,
    })
  }

  // 重置为默认
  const handleReset = () => {
    if (debugSettings) {
      setCustomPrompt('')
      setRagSettings({
        enabled: true,
        max_memories: 5,
        max_recent_messages: 10,
        time_decay_factor: 0.1,
        min_relevance_score: 0.0,
      })
      setRagCorpus([])
    }
  }

  // 添加语料条目
  const addCorpusItem = () => {
    setRagCorpus([...ragCorpus, { content: '', metadata: {} }])
  }

  // 删除语料条目
  const removeCorpusItem = (index: number) => {
    setRagCorpus(ragCorpus.filter((_, i) => i !== index))
  }

  // 更新语料条目
  const updateCorpusItem = (index: number, content: string) => {
    const updated = [...ragCorpus]
    updated[index] = { ...updated[index], content }
    setRagCorpus(updated)
  }

  if (!isOpen) {
    return (
      <Button
        variant="outline"
        size="sm"
        onClick={onToggle}
        className="fixed bottom-4 right-4 z-50"
      >
        <Settings className="h-4 w-4 mr-2" />
        调试面板
      </Button>
    )
  }

  return (
    <div className="fixed bottom-0 right-0 w-full md:w-[500px] max-h-[70vh] bg-background border-t md:border-l shadow-lg z-50 overflow-hidden flex flex-col">
      {/* 头部 */}
      <div className="flex items-center justify-between p-4 border-b bg-muted/50">
        <div className="flex items-center gap-2">
          <Settings className="h-5 w-5" />
          <span className="font-semibold">调试面板</span>
          <Badge variant="outline" className="text-xs">
            DEV
          </Badge>
        </div>
        <div className="flex items-center gap-2">
          <Button
            variant="ghost"
            size="sm"
            onClick={handleReset}
            disabled={updateMutation.isPending}
          >
            <RotateCcw className="h-4 w-4" />
          </Button>
          <Button
            size="sm"
            onClick={handleSave}
            disabled={updateMutation.isPending}
          >
            {updateMutation.isPending ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Save className="h-4 w-4 mr-1" />
            )}
            保存
          </Button>
          <Button variant="ghost" size="sm" onClick={onToggle}>
            <ChevronDown className="h-4 w-4" />
          </Button>
        </div>
      </div>

      {/* 内容 */}
      <div className="flex-1 overflow-y-auto p-4">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
          </div>
        ) : (
          <Tabs defaultValue="prompt" className="space-y-4">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="prompt">
                <Code className="h-4 w-4 mr-1" />
                提示词
              </TabsTrigger>
              <TabsTrigger value="rag">
                <Database className="h-4 w-4 mr-1" />
                RAG
              </TabsTrigger>
              <TabsTrigger value="corpus">
                语料库
              </TabsTrigger>
            </TabsList>

            {/* 系统提示词 */}
            <TabsContent value="prompt" className="space-y-4">
              {/* 导师原始模板 */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <Label className="text-xs text-muted-foreground">
                    导师原始模板
                  </Label>
                  <Badge variant="secondary" className="text-xs">
                    只读
                  </Badge>
                </div>
                <Textarea
                  value={debugSettings?.mentor_system_prompt_template || ''}
                  readOnly
                  className="h-32 text-xs font-mono bg-muted/30"
                />
              </div>

              {/* 自定义提示词 */}
              <div>
                <Label className="text-xs text-muted-foreground mb-2 block">
                  自定义提示词 (覆盖导师模板)
                </Label>
                <Textarea
                  value={customPrompt}
                  onChange={(e) => setCustomPrompt(e.target.value)}
                  placeholder="留空使用导师默认模板...

支持占位符:
{target_name} - 对象名称
{profile_summary} - 画像摘要
{preferences} - 喜好信息
{context} - RAG 检索结果"
                  className="h-40 text-xs font-mono"
                />
              </div>

              {/* 生效的提示词 */}
              <div>
                <div className="flex items-center justify-between mb-2">
                  <Label className="text-xs text-muted-foreground">
                    当前生效的提示词 (渲染后)
                  </Label>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => setShowEffectivePrompt(!showEffectivePrompt)}
                  >
                    {showEffectivePrompt ? (
                      <EyeOff className="h-4 w-4" />
                    ) : (
                      <Eye className="h-4 w-4" />
                    )}
                  </Button>
                </div>
                {showEffectivePrompt && (
                  <Textarea
                    value={debugSettings?.effective_system_prompt || ''}
                    readOnly
                    className="h-48 text-xs font-mono bg-muted/30"
                  />
                )}
              </div>
            </TabsContent>

            {/* RAG 设置 */}
            <TabsContent value="rag" className="space-y-6">
              {/* 启用 RAG */}
              <div className="flex items-center justify-between">
                <div>
                  <Label>启用 RAG 检索</Label>
                  <p className="text-xs text-muted-foreground">
                    从记忆库检索相关内容
                  </p>
                </div>
                <Switch
                  checked={ragSettings.enabled}
                  onCheckedChange={(checked) =>
                    setRagSettings({ ...ragSettings, enabled: checked })
                  }
                />
              </div>

              {/* 最大记忆数 */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label>最大检索记忆数</Label>
                  <span className="text-sm font-mono">
                    {ragSettings.max_memories}
                  </span>
                </div>
                <Slider
                  value={[ragSettings.max_memories]}
                  onValueChange={([value]) =>
                    setRagSettings({ ...ragSettings, max_memories: value })
                  }
                  min={0}
                  max={20}
                  step={1}
                  disabled={!ragSettings.enabled}
                />
              </div>

              {/* 最大历史消息数 */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label>最大历史消息数</Label>
                  <span className="text-sm font-mono">
                    {ragSettings.max_recent_messages}
                  </span>
                </div>
                <Slider
                  value={[ragSettings.max_recent_messages]}
                  onValueChange={([value]) =>
                    setRagSettings({
                      ...ragSettings,
                      max_recent_messages: value,
                    })
                  }
                  min={0}
                  max={50}
                  step={1}
                />
              </div>

              {/* 时间衰减因子 */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label>时间衰减因子</Label>
                  <span className="text-sm font-mono">
                    {ragSettings.time_decay_factor.toFixed(2)}
                  </span>
                </div>
                <Slider
                  value={[ragSettings.time_decay_factor * 100]}
                  onValueChange={([value]) =>
                    setRagSettings({
                      ...ragSettings,
                      time_decay_factor: value / 100,
                    })
                  }
                  min={0}
                  max={100}
                  step={1}
                  disabled={!ragSettings.enabled}
                />
                <p className="text-xs text-muted-foreground">
                  越高表示越偏好最近的记忆
                </p>
              </div>

              {/* 最小相关性分数 */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <Label>最小相关性分数</Label>
                  <span className="text-sm font-mono">
                    {ragSettings.min_relevance_score.toFixed(2)}
                  </span>
                </div>
                <Slider
                  value={[ragSettings.min_relevance_score * 100]}
                  onValueChange={([value]) =>
                    setRagSettings({
                      ...ragSettings,
                      min_relevance_score: value / 100,
                    })
                  }
                  min={0}
                  max={100}
                  step={1}
                  disabled={!ragSettings.enabled}
                />
                <p className="text-xs text-muted-foreground">
                  过滤掉相关性低于此分数的结果
                </p>
              </div>
            </TabsContent>

            {/* RAG 语料库 */}
            <TabsContent value="corpus" className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <Label>自定义语料库</Label>
                  <p className="text-xs text-muted-foreground">
                    添加额外的背景知识供 RAG 检索
                  </p>
                </div>
                <Button variant="outline" size="sm" onClick={addCorpusItem}>
                  <Plus className="h-4 w-4 mr-1" />
                  添加
                </Button>
              </div>

              {ragCorpus.length === 0 ? (
                <div className="text-center py-8 text-muted-foreground">
                  <Database className="h-8 w-8 mx-auto mb-2 opacity-50" />
                  <p className="text-sm">暂无自定义语料</p>
                  <p className="text-xs">点击添加按钮添加语料条目</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {ragCorpus.map((item, index) => (
                    <div key={index} className="relative">
                      <Textarea
                        value={item.content}
                        onChange={(e) =>
                          updateCorpusItem(index, e.target.value)
                        }
                        placeholder={`语料 #${index + 1}...`}
                        className="pr-10 text-sm"
                        rows={3}
                      />
                      <Button
                        variant="ghost"
                        size="sm"
                        className="absolute top-2 right-2 h-6 w-6 p-0"
                        onClick={() => removeCorpusItem(index)}
                      >
                        <Trash2 className="h-3 w-3 text-destructive" />
                      </Button>
                    </div>
                  ))}
                </div>
              )}

              <p className="text-xs text-muted-foreground">
                共 {ragCorpus.length} 条语料
              </p>
            </TabsContent>
          </Tabs>
        )}
      </div>
    </div>
  )
}

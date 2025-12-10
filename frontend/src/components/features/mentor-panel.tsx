'use client'

import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  Sparkles,
  PlusCircle,
  Loader2,
  Settings,
  Eye,
  EyeOff,
  Pencil,
  Trash2,
  Plus,
  Database,
} from 'lucide-react'

import { chatApi } from '@/lib/api'
import { AIMentor, AIMentorCreate, AIMentorUpdate, MENTOR_STYLE_OPTIONS, RAGSettings, RAGCorpusItem, DEFAULT_RAG_SETTINGS } from '@/types'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar'
import { Badge } from '@/components/ui/badge'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Switch } from '@/components/ui/switch'
import { useToast } from '@/hooks/use-toast'

// 默认 System Prompt 模板
const DEFAULT_SYSTEM_PROMPT = `你是一位情感咨询师。

## 你正在帮助用户处理与 {target_name} 的关系

### 对方的基本信息
{profile_summary}

### 对方的喜好
{preferences}

### 你们之间发生过的事情
{context}

## 注意事项
- 基于已知信息给出建议，不要编造不存在的细节
- 如果用户透露新信息，自然地接受并记住
- 鼓励用户表达真实感受`

interface MentorPanelProps {
  className?: string
}

export function MentorPanel({ className }: MentorPanelProps) {
  const queryClient = useQueryClient()
  const { toast } = useToast()
  const [dialogOpen, setDialogOpen] = useState(false)
  const [editingMentor, setEditingMentor] = useState<AIMentor | null>(null)
  const [showInactive, setShowInactive] = useState(false)

  // 获取导师列表
  const { data: mentorsData, isLoading } = useQuery({
    queryKey: ['mentors', showInactive],
    queryFn: () => chatApi.listMentors(!showInactive),
  })

  // 创建导师
  const createMutation = useMutation({
    mutationFn: (data: AIMentorCreate) => chatApi.createMentor(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mentors'] })
      toast({ title: '创建成功', description: '导师已添加' })
      setDialogOpen(false)
    },
    onError: (error: Error) => {
      toast({ title: '创建失败', description: error.message, variant: 'destructive' })
    },
  })

  // 更新导师
  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: AIMentorUpdate }) =>
      chatApi.updateMentor(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['mentors'] })
      toast({ title: '更新成功', description: '导师信息已更新' })
      setDialogOpen(false)
      setEditingMentor(null)
    },
    onError: (error: Error) => {
      toast({ title: '更新失败', description: error.message, variant: 'destructive' })
    },
  })

  // 切换激活状态
  const toggleActiveMutation = useMutation({
    mutationFn: ({ id, is_active }: { id: string; is_active: boolean }) =>
      chatApi.updateMentor(id, { is_active }),
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['mentors'] })
      toast({
        title: variables.is_active ? '已启用' : '已停用',
        description: variables.is_active ? '导师已重新启用' : '导师已停用，不会在列表中显示',
      })
    },
    onError: (error: Error) => {
      toast({ title: '操作失败', description: error.message, variant: 'destructive' })
    },
  })

  const handleOpenCreate = () => {
    setEditingMentor(null)
    setDialogOpen(true)
  }

  const handleOpenEdit = (mentor: AIMentor) => {
    setEditingMentor(mentor)
    setDialogOpen(true)
  }

  const mentors = mentorsData?.items || []

  return (
    <div className={cn('space-y-6', className)}>
      {/* 标题栏 */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold tracking-tight">AI 情感导师</h2>
          <p className="text-muted-foreground">
            管理你的情感咨询师，他们会在所有对话中为你提供建议
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2">
            <Switch
              id="show-inactive"
              checked={showInactive}
              onCheckedChange={setShowInactive}
            />
            <Label htmlFor="show-inactive" className="text-sm text-muted-foreground">
              显示已停用
            </Label>
          </div>
          <Button onClick={handleOpenCreate}>
            <PlusCircle className="mr-2 h-4 w-4" />
            添加导师
          </Button>
        </div>
      </div>

      {/* 导师列表 */}
      {isLoading ? (
        <div className="flex justify-center py-12">
          <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
        </div>
      ) : mentors.length === 0 ? (
        <Card>
          <CardContent className="flex flex-col items-center justify-center py-12">
            <Sparkles className="h-12 w-12 text-muted-foreground/50 mb-4" />
            <p className="text-muted-foreground">暂无导师</p>
            <Button variant="outline" className="mt-4" onClick={handleOpenCreate}>
              创建第一个导师
            </Button>
          </CardContent>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {mentors.map((mentor) => (
            <MentorCard
              key={mentor.id}
              mentor={mentor}
              onEdit={() => handleOpenEdit(mentor)}
              onToggleActive={() =>
                toggleActiveMutation.mutate({
                  id: mentor.id,
                  is_active: !mentor.is_active,
                })
              }
              isToggling={toggleActiveMutation.isPending}
            />
          ))}
        </div>
      )}

      {/* 创建/编辑对话框 */}
      <MentorDialog
        open={dialogOpen}
        onOpenChange={(open) => {
          setDialogOpen(open)
          if (!open) setEditingMentor(null)
        }}
        mentor={editingMentor}
        onSubmit={(data) => {
          if (editingMentor) {
            updateMutation.mutate({ id: editingMentor.id, data })
          } else {
            createMutation.mutate(data as AIMentorCreate)
          }
        }}
        isSubmitting={createMutation.isPending || updateMutation.isPending}
      />
    </div>
  )
}

// 导师卡片组件
interface MentorCardProps {
  mentor: AIMentor
  onEdit: () => void
  onToggleActive: () => void
  isToggling?: boolean
}

function MentorCard({ mentor, onEdit, onToggleActive, isToggling }: MentorCardProps) {
  const styleOption = MENTOR_STYLE_OPTIONS.find((s) => s.value === mentor.style_tag)

  return (
    <Card className={cn('relative transition-opacity', !mentor.is_active && 'opacity-60')}>
      <CardHeader className="pb-3">
        <div className="flex items-start gap-3">
          <Avatar className="h-12 w-12">
            {mentor.icon_url ? <AvatarImage src={mentor.icon_url} /> : null}
            <AvatarFallback>
              <Sparkles className="h-5 w-5" />
            </AvatarFallback>
          </Avatar>
          <div className="flex-1 min-w-0">
            <div className="flex items-center gap-2">
              <CardTitle className="text-base truncate">{mentor.name}</CardTitle>
              {!mentor.is_active && (
                <Badge variant="secondary" className="text-xs">
                  已停用
                </Badge>
              )}
            </div>
            {mentor.style_tag && (
              <Badge variant="outline" className="mt-1 text-xs">
                {styleOption?.emoji} {mentor.style_tag}
              </Badge>
            )}
          </div>
        </div>
      </CardHeader>
      <CardContent className="pb-3">
        <CardDescription className="line-clamp-2 text-sm">
          {mentor.description}
        </CardDescription>
      </CardContent>
      <div className="px-6 pb-4 flex items-center gap-2">
        <Button variant="outline" size="sm" className="flex-1" onClick={onEdit}>
          <Pencil className="h-3.5 w-3.5 mr-1" />
          编辑
        </Button>
        <Button
          variant="ghost"
          size="sm"
          onClick={onToggleActive}
          disabled={isToggling}
          className="px-2"
        >
          {isToggling ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : mentor.is_active ? (
            <EyeOff className="h-4 w-4" />
          ) : (
            <Eye className="h-4 w-4" />
          )}
        </Button>
      </div>
    </Card>
  )
}

// 导师编辑对话框
interface MentorDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
  mentor: AIMentor | null
  onSubmit: (data: AIMentorCreate | AIMentorUpdate) => void
  isSubmitting: boolean
}

function MentorDialog({
  open,
  onOpenChange,
  mentor,
  onSubmit,
  isSubmitting,
}: MentorDialogProps) {
  const [formData, setFormData] = useState<{
    name: string
    description: string
    system_prompt_template: string
    icon_url: string
    style_tag: string
    sort_order: number
    default_rag_settings: RAGSettings
    default_rag_corpus: RAGCorpusItem[]
  }>({
    name: '',
    description: '',
    system_prompt_template: DEFAULT_SYSTEM_PROMPT,
    icon_url: '',
    style_tag: '',
    sort_order: 10,
    default_rag_settings: { ...DEFAULT_RAG_SETTINGS },
    default_rag_corpus: [],
  })

  // 当 mentor 变化时重置表单
  const resetForm = () => {
    if (mentor) {
      setFormData({
        name: mentor.name,
        description: mentor.description,
        system_prompt_template: mentor.system_prompt_template,
        icon_url: mentor.icon_url || '',
        style_tag: mentor.style_tag || '',
        sort_order: mentor.sort_order,
        default_rag_settings: mentor.default_rag_settings || { ...DEFAULT_RAG_SETTINGS },
        default_rag_corpus: mentor.default_rag_corpus || [],
      })
    } else {
      setFormData({
        name: '',
        description: '',
        system_prompt_template: DEFAULT_SYSTEM_PROMPT,
        icon_url: '',
        style_tag: '',
        sort_order: 10,
        default_rag_settings: { ...DEFAULT_RAG_SETTINGS },
        default_rag_corpus: [],
      })
    }
  }

  // 当对话框打开时重置表单
  const handleOpenChange = (newOpen: boolean) => {
    if (newOpen) {
      resetForm()
    }
    onOpenChange(newOpen)
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    const submitData = {
      name: formData.name,
      description: formData.description,
      system_prompt_template: formData.system_prompt_template,
      icon_url: formData.icon_url || undefined,
      style_tag: formData.style_tag || undefined,
      sort_order: formData.sort_order,
      default_rag_settings: formData.default_rag_settings,
      default_rag_corpus: formData.default_rag_corpus.length > 0 ? formData.default_rag_corpus : undefined,
    }
    onSubmit(submitData)
  }

  // 添加语料条目
  const addCorpusItem = () => {
    setFormData({
      ...formData,
      default_rag_corpus: [...formData.default_rag_corpus, { content: '' }],
    })
  }

  // 更新语料条目
  const updateCorpusItem = (index: number, content: string) => {
    const newCorpus = [...formData.default_rag_corpus]
    newCorpus[index] = { content }
    setFormData({ ...formData, default_rag_corpus: newCorpus })
  }

  // 删除语料条目
  const removeCorpusItem = (index: number) => {
    const newCorpus = formData.default_rag_corpus.filter((_, i) => i !== index)
    setFormData({ ...formData, default_rag_corpus: newCorpus })
  }

  const isEditing = !!mentor

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="max-w-2xl max-h-[90vh] overflow-hidden flex flex-col">
        <DialogHeader>
          <DialogTitle>{isEditing ? '编辑导师' : '添加新导师'}</DialogTitle>
          <DialogDescription>
            {isEditing
              ? '修改导师的基本信息和系统提示词'
              : '创建一个新的 AI 情感导师，设定独特的咨询风格'}
          </DialogDescription>
        </DialogHeader>

        <form onSubmit={handleSubmit} className="flex-1 overflow-y-auto space-y-4 py-4">
          {/* 基本信息 */}
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="name">导师名称 *</Label>
              <Input
                id="name"
                value={formData.name}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="例如：温柔姐姐"
                required
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="style_tag">风格标签</Label>
              <Select
                value={formData.style_tag}
                onValueChange={(value) => setFormData({ ...formData, style_tag: value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="选择风格" />
                </SelectTrigger>
                <SelectContent>
                  {MENTOR_STYLE_OPTIONS.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.emoji} {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="description">简短描述 *</Label>
            <Textarea
              id="description"
              value={formData.description}
              onChange={(e) => setFormData({ ...formData, description: e.target.value })}
              placeholder="一句话描述这个导师的特点..."
              rows={2}
              required
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="icon_url">头像 URL</Label>
              <Input
                id="icon_url"
                value={formData.icon_url}
                onChange={(e) => setFormData({ ...formData, icon_url: e.target.value })}
                placeholder="https://..."
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="sort_order">排序权重</Label>
              <Input
                id="sort_order"
                type="number"
                value={formData.sort_order}
                onChange={(e) =>
                  setFormData({ ...formData, sort_order: parseInt(e.target.value) || 0 })
                }
                min={0}
              />
              <p className="text-xs text-muted-foreground">数字越小排序越靠前</p>
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="system_prompt_template">系统提示词模板 *</Label>
            <Textarea
              id="system_prompt_template"
              value={formData.system_prompt_template}
              onChange={(e) =>
                setFormData({ ...formData, system_prompt_template: e.target.value })
              }
              placeholder="设定导师的性格、说话方式..."
              rows={12}
              className="font-mono text-sm"
              required
            />
            <p className="text-xs text-muted-foreground">
              可用占位符: {'{target_name}'}, {'{profile_summary}'}, {'{preferences}'}, {'{context}'}
            </p>
          </div>

          {/* RAG 设置部分 */}
          <div className="space-y-4 pt-4 border-t">
            <div className="flex items-center gap-2">
              <Database className="h-4 w-4" />
              <h3 className="font-medium">RAG 设置</h3>
            </div>

            {/* RAG 开关和参数 */}
            <div className="grid grid-cols-2 gap-4">
              <div className="flex items-center gap-2">
                <Switch
                  id="rag_enabled"
                  checked={formData.default_rag_settings.enabled}
                  onCheckedChange={(checked) =>
                    setFormData({
                      ...formData,
                      default_rag_settings: { ...formData.default_rag_settings, enabled: checked },
                    })
                  }
                />
                <Label htmlFor="rag_enabled">启用记忆检索</Label>
              </div>
              <div className="space-y-1">
                <Label htmlFor="max_memories" className="text-xs">最大检索记忆数</Label>
                <Input
                  id="max_memories"
                  type="number"
                  min={0}
                  max={20}
                  value={formData.default_rag_settings.max_memories}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      default_rag_settings: {
                        ...formData.default_rag_settings,
                        max_memories: parseInt(e.target.value) || 0,
                      },
                    })
                  }
                  className="h-8"
                />
              </div>
            </div>

            <div className="grid grid-cols-3 gap-4">
              <div className="space-y-1">
                <Label htmlFor="max_recent_messages" className="text-xs">最大历史消息数</Label>
                <Input
                  id="max_recent_messages"
                  type="number"
                  min={0}
                  max={50}
                  value={formData.default_rag_settings.max_recent_messages}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      default_rag_settings: {
                        ...formData.default_rag_settings,
                        max_recent_messages: parseInt(e.target.value) || 0,
                      },
                    })
                  }
                  className="h-8"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="time_decay_factor" className="text-xs">时间衰减因子</Label>
                <Input
                  id="time_decay_factor"
                  type="number"
                  min={0}
                  max={1}
                  step={0.1}
                  value={formData.default_rag_settings.time_decay_factor}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      default_rag_settings: {
                        ...formData.default_rag_settings,
                        time_decay_factor: parseFloat(e.target.value) || 0,
                      },
                    })
                  }
                  className="h-8"
                />
              </div>
              <div className="space-y-1">
                <Label htmlFor="min_relevance_score" className="text-xs">最小相关性分数</Label>
                <Input
                  id="min_relevance_score"
                  type="number"
                  min={0}
                  max={1}
                  step={0.1}
                  value={formData.default_rag_settings.min_relevance_score}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      default_rag_settings: {
                        ...formData.default_rag_settings,
                        min_relevance_score: parseFloat(e.target.value) || 0,
                      },
                    })
                  }
                  className="h-8"
                />
              </div>
            </div>

            {/* RAG 语料库 */}
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <Label>RAG 语料库</Label>
                <Button type="button" variant="outline" size="sm" onClick={addCorpusItem}>
                  <Plus className="h-3.5 w-3.5 mr-1" />
                  添加语料
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                添加导师专属的知识内容，用于增强对话时的上下文理解
              </p>
              {formData.default_rag_corpus.length > 0 ? (
                <div className="space-y-2">
                  {formData.default_rag_corpus.map((item, index) => (
                    <div key={index} className="flex gap-2">
                      <Textarea
                        value={item.content}
                        onChange={(e) => updateCorpusItem(index, e.target.value)}
                        placeholder="输入知识内容..."
                        rows={2}
                        className="flex-1 text-sm"
                      />
                      <Button
                        type="button"
                        variant="ghost"
                        size="sm"
                        onClick={() => removeCorpusItem(index)}
                        className="h-8 w-8 p-0 shrink-0"
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="text-sm text-muted-foreground py-4 text-center border border-dashed rounded-md">
                  暂无语料，点击上方按钮添加
                </div>
              )}
            </div>
          </div>
        </form>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            取消
          </Button>
          <Button onClick={handleSubmit} disabled={isSubmitting || !formData.name || !formData.description}>
            {isSubmitting ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                保存中...
              </>
            ) : isEditing ? (
              '保存修改'
            ) : (
              '创建导师'
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

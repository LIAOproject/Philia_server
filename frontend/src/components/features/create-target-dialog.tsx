'use client'

import { useState } from 'react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Loader2 } from 'lucide-react'
import { targetApi } from '@/lib/api'
import { Button } from '@/components/ui/button'
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
import { useToast } from '@/hooks/use-toast'

interface CreateTargetDialogProps {
  open: boolean
  onOpenChange: (open: boolean) => void
}

export function CreateTargetDialog({ open, onOpenChange }: CreateTargetDialogProps) {
  const [name, setName] = useState('')
  const [status, setStatus] = useState('pursuing')
  const { toast } = useToast()
  const queryClient = useQueryClient()

  // 创建 mutation
  const createMutation = useMutation({
    mutationFn: () =>
      targetApi.create({
        name,
        current_status: status,
      }),
    onSuccess: (data) => {
      toast({
        title: '创建成功',
        description: `${data.name} 已添加到你的关系列表`,
        variant: 'success',
      })
      queryClient.invalidateQueries({ queryKey: ['targets'] })
      onOpenChange(false)
      setName('')
      setStatus('pursuing')
    },
    onError: () => {
      toast({
        title: '创建失败',
        description: '请稍后重试',
        variant: 'destructive',
      })
    },
  })

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) return
    createMutation.mutate()
  }

  // 状态选项
  const statusOptions = [
    { value: 'pursuing', label: '追求中', emoji: '💗' },
    { value: 'dating', label: '约会中', emoji: '❤️' },
    { value: 'friend', label: '朋友', emoji: '💙' },
    { value: 'complicated', label: '复杂', emoji: '💛' },
  ]

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[425px]">
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>添加新对象</DialogTitle>
            <DialogDescription>
              创建一个新的关系对象，之后可以上传截图让 AI 分析
            </DialogDescription>
          </DialogHeader>

          <div className="grid gap-4 py-4">
            {/* 名称输入 */}
            <div className="grid gap-2">
              <Label htmlFor="name">昵称 / 称呼</Label>
              <Input
                id="name"
                placeholder="例如：小明、Crush、相亲对象1号"
                value={name}
                onChange={(e) => setName(e.target.value)}
                disabled={createMutation.isPending}
                autoFocus
              />
            </div>

            {/* 状态选择 */}
            <div className="grid gap-2">
              <Label>当前关系</Label>
              <div className="grid grid-cols-2 gap-2">
                {statusOptions.map((option) => (
                  <Button
                    key={option.value}
                    type="button"
                    variant={status === option.value ? 'default' : 'outline'}
                    className="justify-start"
                    onClick={() => setStatus(option.value)}
                    disabled={createMutation.isPending}
                  >
                    <span className="mr-2">{option.emoji}</span>
                    {option.label}
                  </Button>
                ))}
              </div>
            </div>
          </div>

          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => onOpenChange(false)}
              disabled={createMutation.isPending}
            >
              取消
            </Button>
            <Button
              type="submit"
              disabled={!name.trim() || createMutation.isPending}
            >
              {createMutation.isPending && (
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              )}
              创建
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

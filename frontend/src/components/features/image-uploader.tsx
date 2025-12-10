'use client'

import { useCallback, useState } from 'react'
import { useDropzone } from 'react-dropzone'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { Upload, Image as ImageIcon, Loader2, Check, AlertCircle } from 'lucide-react'
import { cn } from '@/lib/utils'
import { uploadApi } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Progress } from '@/components/ui/progress'
import { useToast } from '@/hooks/use-toast'
import type { UploadResponse, SOURCE_TYPE_OPTIONS } from '@/types'

interface ImageUploaderProps {
  targetId: string
  onSuccess?: (result: UploadResponse) => void
  className?: string
}

type SourceType = typeof SOURCE_TYPE_OPTIONS[number]['value']

export function ImageUploader({ targetId, onSuccess, className }: ImageUploaderProps) {
  const [preview, setPreview] = useState<string | null>(null)
  const [sourceType, setSourceType] = useState<SourceType>('wechat')
  const { toast } = useToast()
  const queryClient = useQueryClient()

  // 上传 mutation
  const uploadMutation = useMutation({
    mutationFn: async (file: File) => {
      return uploadApi.analyze(file, targetId, { source_type: sourceType })
    },
    onSuccess: (data) => {
      toast({
        title: '分析完成',
        description: `创建了 ${data.memories_created} 条记忆${data.profile_updated ? '，档案已更新' : ''}`,
        variant: 'success',
      })
      // 刷新相关数据
      queryClient.invalidateQueries({ queryKey: ['target', targetId] })
      queryClient.invalidateQueries({ queryKey: ['memories', targetId] })
      queryClient.invalidateQueries({ queryKey: ['targets'] })
      // 清除预览
      setPreview(null)
      onSuccess?.(data)
    },
    onError: (error: Error) => {
      toast({
        title: '上传失败',
        description: error.message || '请稍后重试',
        variant: 'destructive',
      })
    },
  })

  // 处理文件选择
  const onDrop = useCallback(
    (acceptedFiles: File[]) => {
      const file = acceptedFiles[0]
      if (!file) return

      // 创建预览
      const reader = new FileReader()
      reader.onload = () => {
        setPreview(reader.result as string)
      }
      reader.readAsDataURL(file)

      // 开始上传
      uploadMutation.mutate(file)
    },
    [uploadMutation]
  )

  const { getRootProps, getInputProps, isDragActive } = useDropzone({
    onDrop,
    accept: {
      'image/*': ['.png', '.jpg', '.jpeg', '.gif', '.webp'],
    },
    maxSize: 10 * 1024 * 1024, // 10MB
    multiple: false,
    disabled: uploadMutation.isPending,
  })

  // 来源类型选项
  const sourceOptions: { value: SourceType; label: string; icon: string }[] = [
    { value: 'wechat', label: '微信', icon: '💬' },
    { value: 'qq', label: 'QQ', icon: '🐧' },
    { value: 'tantan', label: '探探', icon: '💕' },
    { value: 'soul', label: 'Soul', icon: '👻' },
    { value: 'xiaohongshu', label: '小红书', icon: '📕' },
    { value: 'photo', label: '照片', icon: '📷' },
  ]

  return (
    <div className={cn('space-y-4', className)}>
      {/* 来源类型选择 */}
      <div className="flex flex-wrap gap-2">
        {sourceOptions.map((option) => (
          <Button
            key={option.value}
            variant={sourceType === option.value ? 'default' : 'outline'}
            size="sm"
            onClick={() => setSourceType(option.value)}
            disabled={uploadMutation.isPending}
          >
            <span className="mr-1">{option.icon}</span>
            {option.label}
          </Button>
        ))}
      </div>

      {/* 拖拽上传区域 */}
      <div
        {...getRootProps()}
        className={cn(
          'relative border-2 border-dashed rounded-lg p-8 transition-colors cursor-pointer',
          isDragActive
            ? 'border-primary bg-primary/5'
            : 'border-muted-foreground/25 hover:border-primary/50',
          uploadMutation.isPending && 'pointer-events-none opacity-60'
        )}
      >
        <input {...getInputProps()} />

        {preview ? (
          // 图片预览
          <div className="relative">
            <img
              src={preview}
              alt="预览"
              className="max-h-64 mx-auto rounded-lg object-contain"
            />
            {uploadMutation.isPending && (
              <div className="absolute inset-0 flex items-center justify-center bg-background/80 rounded-lg">
                <div className="text-center">
                  <Loader2 className="h-8 w-8 animate-spin mx-auto text-primary" />
                  <p className="mt-2 text-sm text-muted-foreground">AI 正在分析...</p>
                </div>
              </div>
            )}
            {uploadMutation.isSuccess && (
              <div className="absolute top-2 right-2 bg-green-500 text-white rounded-full p-1">
                <Check className="h-4 w-4" />
              </div>
            )}
          </div>
        ) : (
          // 上传提示
          <div className="text-center">
            {isDragActive ? (
              <>
                <ImageIcon className="h-12 w-12 mx-auto text-primary" />
                <p className="mt-2 text-primary">放开以上传图片</p>
              </>
            ) : (
              <>
                <Upload className="h-12 w-12 mx-auto text-muted-foreground" />
                <p className="mt-2 text-muted-foreground">
                  拖拽图片到这里，或点击选择文件
                </p>
                <p className="mt-1 text-xs text-muted-foreground">
                  支持 PNG, JPG, GIF, WebP，最大 10MB
                </p>
              </>
            )}
          </div>
        )}
      </div>

      {/* 上传进度 */}
      {uploadMutation.isPending && (
        <Progress value={undefined} className="h-2" />
      )}

      {/* 分析结果预览 */}
      {uploadMutation.isSuccess && uploadMutation.data?.analysis_result && (
        <div className="rounded-lg border bg-muted/50 p-4 animate-fade-in">
          <h4 className="font-medium mb-2 flex items-center gap-2">
            <Check className="h-4 w-4 text-green-500" />
            AI 分析结果
          </h4>
          <div className="space-y-2 text-sm">
            <p>
              <span className="text-muted-foreground">图片类型：</span>
              {uploadMutation.data.analysis_result.image_type}
              <span className="text-muted-foreground ml-2">
                (置信度: {(uploadMutation.data.analysis_result.confidence * 100).toFixed(0)}%)
              </span>
            </p>
            {(uploadMutation.data.analysis_result.profile_updates?.tags_to_add?.length ?? 0) > 0 && (
              <p>
                <span className="text-muted-foreground">新标签：</span>
                {uploadMutation.data.analysis_result.profile_updates?.tags_to_add?.join(', ')}
              </p>
            )}
            {uploadMutation.data.analysis_result.new_memories?.length > 0 && (
              <p>
                <span className="text-muted-foreground">情绪：</span>
                {uploadMutation.data.analysis_result.new_memories[0].sentiment}
              </p>
            )}
          </div>
        </div>
      )}

      {/* 错误提示 */}
      {uploadMutation.isError && (
        <div className="rounded-lg border border-destructive bg-destructive/10 p-4 flex items-start gap-3">
          <AlertCircle className="h-5 w-5 text-destructive shrink-0" />
          <div>
            <p className="font-medium text-destructive">上传失败</p>
            <p className="text-sm text-muted-foreground">
              {(uploadMutation.error as Error)?.message || '请检查网络连接后重试'}
            </p>
          </div>
        </div>
      )}
    </div>
  )
}

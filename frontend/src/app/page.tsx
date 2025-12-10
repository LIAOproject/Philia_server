'use client'

import { useState } from 'react'
import { TargetList } from '@/components/features/target-list'
import { MentorPanel } from '@/components/features/mentor-panel'
import { CreateTargetDialog } from '@/components/features/create-target-dialog'
import { Button } from '@/components/ui/button'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { PlusCircle, Heart, Users, Sparkles } from 'lucide-react'

export default function HomePage() {
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [activeTab, setActiveTab] = useState('relations')

  return (
    <div className="min-h-screen bg-gradient-to-b from-background to-muted/20">
      {/* 顶部导航 */}
      <header className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60">
        <div className="container flex h-16 items-center">
          <div className="flex items-center gap-2">
            <Heart className="h-6 w-6 text-primary" />
            <h1 className="text-xl font-bold">Philia</h1>
          </div>
        </div>
      </header>

      {/* 主内容 */}
      <main className="container py-8">
        <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
          <TabsList className="grid w-full max-w-md grid-cols-2">
            <TabsTrigger value="relations" className="gap-2">
              <Users className="h-4 w-4" />
              我的关系
            </TabsTrigger>
            <TabsTrigger value="mentors" className="gap-2">
              <Sparkles className="h-4 w-4" />
              导师
            </TabsTrigger>
          </TabsList>

          <TabsContent value="relations" className="space-y-6">
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold tracking-tight">我的关系</h2>
                <p className="text-muted-foreground">
                  管理你的人际关系，上传截图让 AI 帮你分析
                </p>
              </div>
              <Button onClick={() => setShowCreateDialog(true)}>
                <PlusCircle className="mr-2 h-4 w-4" />
                添加对象
              </Button>
            </div>
            <TargetList />
          </TabsContent>

          <TabsContent value="mentors">
            <MentorPanel />
          </TabsContent>
        </Tabs>
      </main>

      {/* 创建对象对话框 */}
      <CreateTargetDialog
        open={showCreateDialog}
        onOpenChange={setShowCreateDialog}
      />
    </div>
  )
}

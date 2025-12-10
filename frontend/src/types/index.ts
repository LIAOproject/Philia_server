// Relation-OS 类型定义

// ========================
// Target (关系对象) 类型
// ========================

export interface ProfileData {
  tags?: string[]
  mbti?: string
  zodiac?: string
  age_range?: string
  occupation?: string
  location?: string
  education?: string
  appearance?: Record<string, string>
  personality?: Record<string, string>
}

export interface Preferences {
  likes: string[]
  dislikes: string[]
}

export interface Target {
  id: string
  name: string
  avatar_url?: string
  current_status?: string
  profile_data: ProfileData
  preferences: Preferences
  ai_summary?: string
  created_at: string
  updated_at: string
  memory_count?: number
}

export interface TargetCreate {
  name: string
  avatar_url?: string
  current_status?: string
  profile_data?: ProfileData
  preferences?: Preferences
}

export interface TargetUpdate {
  name?: string
  avatar_url?: string
  current_status?: string
  profile_data?: ProfileData
  preferences?: Preferences
  ai_summary?: string
}

export interface TargetListResponse {
  total: number
  items: Target[]
}

// ========================
// Memory (记忆) 类型
// ========================

export interface ExtractedFacts {
  sentiment?: string
  key_event?: string
  topics?: string[]
  subtext?: string
  red_flags?: string[]
  green_flags?: string[]
  image_type?: string
  notes?: string
}

export interface Memory {
  id: string
  target_id: string
  happened_at: string
  source_type: string
  content?: string
  image_url?: string
  extracted_facts: ExtractedFacts
  sentiment_score: number
  created_at: string
}

export interface MemoryListResponse {
  total: number
  items: Memory[]
}

// ========================
// AI 分析结果类型
// ========================

export interface ProfileUpdate {
  tags_to_add?: string[]
  mbti?: string
  zodiac?: string
  age_range?: string
  occupation?: string
  location?: string
  appearance_updates?: Record<string, string>
  personality_updates?: Record<string, string>
  likes_to_add?: string[]
  dislikes_to_add?: string[]
}

export interface NewMemory {
  happened_at?: string
  content_summary: string
  sentiment: string
  sentiment_score: number
  key_event?: string
  topics?: string[]
  subtext?: string
  red_flags?: string[]
  green_flags?: string[]
  conversation_fingerprint?: string
}

export interface AIAnalysisResult {
  image_type: string
  confidence: number
  profile_updates: ProfileUpdate
  new_memories: NewMemory[]
  raw_text_extracted?: string
  analysis_notes?: string
}

export interface UploadResponse {
  success: boolean
  message: string
  image_url?: string
  analysis_result?: AIAnalysisResult
  memories_created: number
  profile_updated: boolean
}

// ========================
// 通用类型
// ========================

export interface MessageResponse {
  success: boolean
  message: string
}

// 关系状态选项
export const RELATIONSHIP_STATUS_OPTIONS = [
  { value: 'pursuing', label: '追求中', color: 'bg-pink-500' },
  { value: 'dating', label: '约会中', color: 'bg-red-500' },
  { value: 'friend', label: '朋友', color: 'bg-blue-500' },
  { value: 'complicated', label: '复杂', color: 'bg-yellow-500' },
  { value: 'ended', label: '已结束', color: 'bg-gray-500' },
] as const

// 来源类型选项
export const SOURCE_TYPE_OPTIONS = [
  { value: 'wechat', label: '微信', icon: '💬' },
  { value: 'qq', label: 'QQ', icon: '🐧' },
  { value: 'tantan', label: '探探', icon: '💕' },
  { value: 'soul', label: 'Soul', icon: '👻' },
  { value: 'xiaohongshu', label: '小红书', icon: '📕' },
  { value: 'photo', label: '照片', icon: '📷' },
  { value: 'manual', label: '手动', icon: '✍️' },
] as const

export type RelationshipStatus = typeof RELATIONSHIP_STATUS_OPTIONS[number]['value']
export type SourceType = typeof SOURCE_TYPE_OPTIONS[number]['value']

// ========================
// Chat (聊天) 类型
// ========================

// RAG 设置
export interface RAGSettings {
  enabled: boolean
  max_memories: number
  max_recent_messages: number
  time_decay_factor: number
  min_relevance_score: number
}

// RAG 语料条目
export interface RAGCorpusItem {
  content: string
  metadata?: Record<string, unknown>
}

// 默认 RAG 设置
export const DEFAULT_RAG_SETTINGS: RAGSettings = {
  enabled: true,
  max_memories: 5,
  max_recent_messages: 10,
  time_decay_factor: 0.1,
  min_relevance_score: 0.0,
}

export interface AIMentor {
  id: string
  name: string
  description: string
  system_prompt_template: string
  icon_url?: string
  style_tag?: string
  is_active: boolean
  sort_order: number
  default_rag_settings: RAGSettings
  default_rag_corpus: RAGCorpusItem[]
  created_at: string
  updated_at: string
}

export interface AIMentorCreate {
  name: string
  description: string
  system_prompt_template: string
  icon_url?: string
  style_tag?: string
  sort_order?: number
  default_rag_settings?: RAGSettings
  default_rag_corpus?: RAGCorpusItem[]
}

export interface AIMentorUpdate {
  name?: string
  description?: string
  system_prompt_template?: string
  icon_url?: string
  style_tag?: string
  is_active?: boolean
  sort_order?: number
  default_rag_settings?: RAGSettings
  default_rag_corpus?: RAGCorpusItem[]
}

export interface AIMentorListResponse {
  total: number
  items: AIMentor[]
}

export interface Chatbot {
  id: string
  target_id: string
  mentor_id: string
  title: string
  status: 'active' | 'archived'
  created_at: string
  updated_at: string
  target_name?: string
  mentor_name?: string
  mentor_icon_url?: string
  message_count?: number
}

export interface ChatbotCreate {
  target_id: string
  mentor_id: string
  title?: string
}

export interface ChatbotListResponse {
  total: number
  items: Chatbot[]
}

export interface ChatMessage {
  id: string
  chatbot_id: string
  role: 'user' | 'assistant'
  content: string
  created_at: string
}

export interface ChatMessageListResponse {
  total: number
  items: ChatMessage[]
}

export interface SendMessageRequest {
  message: string
}

export interface SendMessageResponse {
  user_message: ChatMessage
  assistant_message: ChatMessage
  memories_retrieved: number
  memory_created: boolean
}

export interface ChatbotDetail extends Chatbot {
  recent_messages: ChatMessage[]
}

// ========================
// 调试设置类型
// ========================

export interface RAGSettings {
  enabled: boolean
  max_memories: number
  max_recent_messages: number
  time_decay_factor: number
  min_relevance_score: number
}

export interface RAGCorpusItem {
  content: string
  metadata?: Record<string, unknown>
}

export interface ChatbotDebugSettings {
  id: string
  mentor_system_prompt_template: string
  custom_system_prompt?: string
  effective_system_prompt?: string
  rag_settings: RAGSettings
  rag_corpus: RAGCorpusItem[]
}

export interface ChatbotDebugSettingsUpdate {
  custom_system_prompt?: string
  rag_settings?: RAGSettings
  rag_corpus?: RAGCorpusItem[]
}

// 导师风格选项
export const MENTOR_STYLE_OPTIONS = [
  { value: '温柔共情', label: '温柔共情', emoji: '💕' },
  { value: '犀利直接', label: '犀利直接', emoji: '🔥' },
  { value: '理性分析', label: '理性分析', emoji: '📊' },
  { value: '实战指导', label: '实战指导', emoji: '🎯' },
  { value: '心理探索', label: '心理探索', emoji: '🧠' },
] as const

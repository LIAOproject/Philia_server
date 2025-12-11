# Philia iOS Client

AI-powered relationship management iOS app built with SwiftUI.

## Requirements

- iOS 16.0+
- Xcode 15.0+
- Swift 5.9+

## Getting Started

### 1. Open the Project

```bash
open Philia.xcodeproj
```

Or double-click `Philia.xcodeproj` in Finder.

### 2. Configure Signing

1. Select the project in Xcode
2. Go to "Signing & Capabilities"
3. Select your development team
4. Update the Bundle Identifier if needed

### 3. Run the App

1. Select a simulator or connected device
2. Press `Cmd + R` to build and run

## Project Structure

```
Philia/
├── PhiliaApp.swift           # App entry point
├── ContentView.swift         # Root navigation
│
├── Models/                   # Data models
│   ├── Target.swift         # Relationship target
│   ├── Memory.swift         # Events/memories
│   ├── Mentor.swift         # AI mentors
│   ├── Chatbot.swift        # Chat sessions
│   └── ChatMessage.swift    # Messages
│
├── Services/                 # API layer
│   ├── APIClient.swift      # HTTP client
│   ├── TargetService.swift  # Target CRUD
│   ├── MemoryService.swift  # Memory operations
│   ├── UploadService.swift  # Image upload
│   └── ChatService.swift    # Chat & streaming
│
├── Views/
│   ├── Home/                # Home screen
│   ├── Target/              # Target detail (3 tabs)
│   ├── Chat/                # Chat interface
│   ├── Upload/              # Image upload
│   └── Settings/            # Settings page
│
├── Components/              # Reusable UI
│   ├── StatusBadge.swift
│   ├── LoadingView.swift
│   ├── EmptyStateView.swift
│   └── AsyncImageView.swift
│
└── Utils/
    └── Constants.swift      # App constants
```

## Features

### Home Screen
- Target card list with status badges
- Floating "+" button to create new targets
- Philia avatar in top-right for settings

### Target Detail (3 Tabs)
1. **Profile**: Uploaded images grid with AI analysis
2. **Consult**: Chatbot list, create new chats with AI mentors
3. **Analysis**: AI summary, editable profile data, preferences

### Chat
- Full-screen chat interface
- SSE streaming for AI responses
- Message history

### Image Upload
- Photo picker integration
- Source type selection (WeChat, QQ, etc.)
- AI analysis results display

## API Configuration

The app connects to the Philia backend API. Default server:
```
http://14.103.211.140:8000/api/v1
```

You can change the API URL in Settings.

## Backend Requirements

Make sure the Philia backend is running with:
- `/api/v1/targets` - Target CRUD
- `/api/v1/memories` - Memory operations
- `/api/v1/upload/analyze` - Image upload + AI analysis
- `/api/v1/chat/mentors` - AI mentor list
- `/api/v1/chat/chatbots` - Chat session management
- `/api/v1/chat/chatbots/{id}/send/stream` - SSE streaming

## Troubleshooting

### Build Errors

If you see build errors after opening the project:

1. Clean build folder: `Cmd + Shift + K`
2. Delete derived data: `~/Library/Developer/Xcode/DerivedData`
3. Restart Xcode

### Network Issues

- Ensure the backend server is running
- Check the API URL in Settings
- For local development, use your Mac's IP instead of localhost

### Missing App Icon

Add a 1024x1024 PNG image to:
```
Philia/Assets.xcassets/AppIcon.appiconset/
```

## License

MIT License

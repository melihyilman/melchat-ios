#!/bin/bash

# MelChat Project Organization Script
# This script organizes your project files into a proper structure

echo "🚀 Starting MelChat project organization..."

# Create directory structure
echo "📁 Creating directory structure..."

# Core directories
mkdir -p MelChat/App
mkdir -p MelChat/Models
mkdir -p MelChat/Views
mkdir -p MelChat/ViewModels
mkdir -p MelChat/Services/Network
mkdir -p MelChat/Services/Encryption
mkdir -p MelChat/Services/Storage
mkdir -p MelChat/Helpers
mkdir -p MelChat/Extensions
mkdir -p MelChat/Resources

# Tests directory
mkdir -p MelChatTests

# Move files to their proper locations
echo "📦 Moving files..."

# App files
[ -f "MelChatApp.swift" ] && mv MelChatApp.swift MelChat/App/

# Models
[ -f "User.swift" ] && mv User.swift MelChat/Models/
[ -f "Message.swift" ] && mv Message.swift MelChat/Models/
[ -f "Conversation.swift" ] && mv Conversation.swift MelChat/Models/

# Views
[ -f "ContentView.swift" ] && mv ContentView.swift MelChat/Views/
[ -f "LoginView.swift" ] && mv LoginView.swift MelChat/Views/
[ -f "RegisterView.swift" ] && mv RegisterView.swift MelChat/Views/
[ -f "ConversationListView.swift" ] && mv ConversationListView.swift MelChat/Views/
[ -f "ChatView.swift" ] && mv ChatView.swift MelChat/Views/
[ -f "MessageRow.swift" ] && mv MessageRow.swift MelChat/Views/

# ViewModels
[ -f "AuthViewModel.swift" ] && mv AuthViewModel.swift MelChat/ViewModels/
[ -f "ConversationViewModel.swift" ] && mv ConversationViewModel.swift MelChat/ViewModels/
[ -f "ChatViewModel.swift" ] && mv ChatViewModel.swift MelChat/ViewModels/

# Services - Network
[ -f "APIService.swift" ] && mv APIService.swift MelChat/Services/Network/
[ -f "WebSocketService.swift" ] && mv WebSocketService.swift MelChat/Services/Network/
[ -f "NetworkManager.swift" ] && mv NetworkManager.swift MelChat/Services/Network/

# Services - Encryption
[ -f "EncryptionService.swift" ] && mv EncryptionService.swift MelChat/Services/Encryption/
[ -f "KeyManager.swift" ] && mv KeyManager.swift MelChat/Services/Encryption/

# Services - Storage
[ -f "KeychainHelper.swift" ] && mv KeychainHelper.swift MelChat/Services/Storage/
[ -f "CoreDataManager.swift" ] && mv CoreDataManager.swift MelChat/Services/Storage/

# Helpers
[ -f "Constants.swift" ] && mv Constants.swift MelChat/Helpers/
[ -f "Utilities.swift" ] && mv Utilities.swift MelChat/Helpers/

# Extensions
[ -f "String+Extensions.swift" ] && mv String+Extensions.swift MelChat/Extensions/
[ -f "Date+Extensions.swift" ] && mv Date+Extensions.swift MelChat/Extensions/

# Test files
[ -f "KeychainHelperTests.swift" ] && mv KeychainHelperTests.swift MelChatTests/
[ -f "EncryptionServiceTests.swift" ] && mv EncryptionServiceTests.swift MelChatTests/

echo "✅ File organization complete!"
echo ""
echo "📋 Project Structure:"
echo "MelChat/"
echo "├── App/"
echo "├── Models/"
echo "├── Views/"
echo "├── ViewModels/"
echo "├── Services/"
echo "│   ├── Network/"
echo "│   ├── Encryption/"
echo "│   └── Storage/"
echo "├── Helpers/"
echo "├── Extensions/"
echo "└── Resources/"
echo ""
echo "MelChatTests/"
echo ""
echo "🎉 Done! Your project is now organized."
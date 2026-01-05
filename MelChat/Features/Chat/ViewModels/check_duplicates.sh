#!/bin/bash
# Find duplicate .swift files in project

echo "🔍 Searching for Swift files..."
echo ""

# Find all Swift files (excluding DerivedData, build folders)
find . -name "*.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" | sort

echo ""
echo "---"
echo "📊 Checking for duplicates..."
echo ""

# Check for duplicate Models.swift
echo "Models.swift:"
find . -name "Models.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" | sort

echo ""
echo "KeychainHelper.swift:"
find . -name "KeychainHelper.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" | sort

echo ""
echo "NetworkLogger.swift:"
find . -name "NetworkLogger.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" | sort

echo ""
echo "---"
echo "✅ Done! If you see multiple paths for same file, you have duplicates."
echo "👉 In Xcode: Select duplicate → Right Click → Delete → Remove Reference"

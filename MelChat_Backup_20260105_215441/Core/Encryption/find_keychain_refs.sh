#!/bin/bash
# Find which files reference KeychainHelper

echo "🔍 KEYCHAINHELPER REFERENCES"
echo "=============================="
echo ""

echo "Files that import or use KeychainHelper:"
grep -r "KeychainHelper" . \
    --include="*.swift" \
    --exclude-dir=DerivedData \
    --exclude-dir=Build \
    | grep -v "Binary file" \
    | head -20

echo ""
echo "=============================="
echo ""
echo "KeychainHelper.swift location:"
find . -name "KeychainHelper.swift" -not -path "*/DerivedData/*" -type f

echo ""
echo "=============================="

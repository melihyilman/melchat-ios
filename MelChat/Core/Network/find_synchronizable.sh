#!/bin/bash
# Find all synchronizable parameter usage

echo "🔍 SYNCHRONIZABLE USAGE"
echo "======================="
echo ""

grep -rn "synchronizable:" . \
    --include="*.swift" \
    --exclude-dir=DerivedData \
    --exclude-dir=Build

echo ""
echo "======================="

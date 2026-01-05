#!/bin/bash
# PROJECT STRUCTURE ANALYSIS - Find all Swift files and categorize them

echo "🔍 MELCHAT PROJECT STRUCTURE ANALYSIS"
echo "======================================"
echo ""

# Find all Swift files (excluding DerivedData, Build, etc.)
echo "📁 ALL SWIFT FILES:"
echo "-------------------"
find . -name "*.swift" \
    -not -path "*/DerivedData/*" \
    -not -path "*/Build/*" \
    -not -path "*/.build/*" \
    -not -path "*/Pods/*" \
    -type f \
    | sort

echo ""
echo "======================================"
echo "📊 FILE STATISTICS:"
echo "-------------------"

# Count files by category
echo "Models: $(find . -name "*Model*.swift" -o -name "Models.swift" -not -path "*/DerivedData/*" -type f | wc -l)"
echo "ViewModels: $(find . -name "*ViewModel*.swift" -not -path "*/DerivedData/*" -type f | wc -l)"
echo "Views: $(find . -name "*View*.swift" -not -path "*/DerivedData/*" -type f | wc -l)"
echo "Services/Managers: $(find . -name "*Manager*.swift" -o -name "*Service*.swift" -o -name "*Client*.swift" -not -path "*/DerivedData/*" -type f | wc -l)"
echo "Helpers: $(find . -name "*Helper*.swift" -not -path "*/DerivedData/*" -type f | wc -l)"

echo ""
echo "======================================"
echo "🔍 POTENTIAL DUPLICATES:"
echo "------------------------"

# Check for duplicate encryption services
echo ""
echo "Encryption related files:"
find . \( -iname "*encrypt*.swift" -o -iname "*crypto*.swift" \) \
    -not -path "*/DerivedData/*" \
    -not -path "*/Build/*" \
    -type f

# Check for duplicate model files
echo ""
echo "Model files:"
find . -name "*Model*.swift" -o -name "Models.swift" \
    -not -path "*/DerivedData/*" \
    -type f

# Check for duplicate helper files
echo ""
echo "Helper files:"
find . -name "*Helper*.swift" \
    -not -path "*/DerivedData/*" \
    -type f

echo ""
echo "======================================"
echo "✅ Analysis complete!"
echo ""

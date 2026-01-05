#!/bin/bash
# Find exact duplicate file locations

echo "🔍 Checking for duplicate Swift files..."
echo ""
echo "==================================="
echo "Models.swift:"
echo "==================================="
find . -name "Models.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" -type f -exec echo "📄 {}" \; -exec wc -l {} \;

echo ""
echo "==================================="
echo "KeychainHelper.swift:"
echo "==================================="
find . -name "KeychainHelper.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" -type f -exec echo "📄 {}" \; -exec wc -l {} \;

echo ""
echo "==================================="
echo "NetworkLogger.swift:"
echo "==================================="
find . -name "NetworkLogger.swift" -not -path "*/DerivedData/*" -not -path "*/Build/*" -not -path "*/.build/*" -type f -exec echo "📄 {}" \; -exec wc -l {} \;

echo ""
echo "==================================="
echo "✅ Analysis:"
echo "==================================="
echo "- Her dosya için SADECE 1 path görünmeli"
echo "- Eğer 2+ path varsa, DUPLICATE VAR!"
echo "- Büyük olan (daha fazla satır) → GERÇEK DOSYA (BUNU TUTACAKSIN)"
echo "- Küçük olan → DUPLICATE (XCODE'DA BUNU SİL)"
echo ""

#!/bin/bash

# 🔍 MelChat Duplicate & Deprecated Files Checker
# Finds duplicate implementations and old encryption files

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e "${BOLD}${BLUE}  MelChat Duplicate & Deprecated Checker${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}\n"

cd /Users/melih/dev/melchat/MelChat/MelChat

ISSUES=0

# ============================================
# 1. ENCRYPTION FILES
# ============================================
echo -e "${BOLD}📦 Encryption files:${NC}"
ENCRYPTION_FILES=$(find . -name "*Encrypt*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | wc -l)
find . -name "*Encrypt*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | while read file; do
    echo -e "  ${GREEN}✅ $file${NC}"
done

if [ "$ENCRYPTION_FILES" -gt 1 ]; then
    echo -e "  ${RED}❌ WARNING: Found $ENCRYPTION_FILES encryption files (should be 1!)${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$ENCRYPTION_FILES" -eq 1 ]; then
    echo -e "  ${GREEN}✅ OK: Only 1 encryption file${NC}"
else
    echo -e "  ${RED}❌ ERROR: No encryption file found!${NC}"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# ============================================
# 2. KEYCHAIN FILES
# ============================================
echo -e "${BOLD}🔑 Keychain files:${NC}"
KEYCHAIN_FILES=$(find . -name "*Keychain*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | wc -l)
find . -name "*Keychain*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | while read file; do
    echo -e "  ${GREEN}✅ $file${NC}"
done

if [ "$KEYCHAIN_FILES" -gt 1 ]; then
    echo -e "  ${RED}❌ WARNING: Found $KEYCHAIN_FILES keychain files (should be 1!)${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$KEYCHAIN_FILES" -eq 1 ]; then
    echo -e "  ${GREEN}✅ OK: Only 1 keychain file${NC}"
else
    echo -e "  ${RED}❌ ERROR: No keychain file found!${NC}"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# ============================================
# 3. MODELS FILES
# ============================================
echo -e "${BOLD}📋 Models files:${NC}"
MODELS_FILES=$(find . -name "Models.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | wc -l)
find . -name "Models.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | while read file; do
    echo -e "  ${GREEN}✅ $file${NC}"
done

if [ "$MODELS_FILES" -gt 1 ]; then
    echo -e "  ${RED}❌ WARNING: Found $MODELS_FILES Models.swift files (should be 1!)${NC}"
    echo -e "  ${YELLOW}💡 Keep the largest one, delete others${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$MODELS_FILES" -eq 1 ]; then
    echo -e "  ${GREEN}✅ OK: Only 1 Models.swift file${NC}"
else
    echo -e "  ${RED}❌ ERROR: No Models.swift found!${NC}"
    ISSUES=$((ISSUES + 1))
fi
echo ""

# ============================================
# 4. TOKEN MANAGER FILES
# ============================================
echo -e "${BOLD}🎫 TokenManager files:${NC}"
TOKEN_FILES=$(find . -name "*TokenManager*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | wc -l)
find . -name "*TokenManager*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | while read file; do
    echo -e "  ${GREEN}✅ $file${NC}"
done

if [ "$TOKEN_FILES" -gt 1 ]; then
    echo -e "  ${RED}❌ WARNING: Found $TOKEN_FILES TokenManager files (should be 1!)${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$TOKEN_FILES" -eq 1 ]; then
    echo -e "  ${GREEN}✅ OK: Only 1 TokenManager file${NC}"
elif [ "$TOKEN_FILES" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  No TokenManager found (might be OK if not using JWT)${NC}"
fi
echo ""

# ============================================
# 5. NETWORK LOGGER FILES
# ============================================
echo -e "${BOLD}📡 NetworkLogger files:${NC}"
LOGGER_FILES=$(find . -name "*NetworkLogger*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | wc -l)
find . -name "*NetworkLogger*.swift" -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f | while read file; do
    echo -e "  ${GREEN}✅ $file${NC}"
done

if [ "$LOGGER_FILES" -gt 1 ]; then
    echo -e "  ${RED}❌ WARNING: Found $LOGGER_FILES NetworkLogger files (should be 1!)${NC}"
    ISSUES=$((ISSUES + 1))
elif [ "$LOGGER_FILES" -eq 1 ]; then
    echo -e "  ${GREEN}✅ OK: Only 1 NetworkLogger file${NC}"
elif [ "$LOGGER_FILES" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠️  No NetworkLogger found${NC}"
fi
echo ""

# ============================================
# 6. DEPRECATED ENCRYPTION (MUST BE EMPTY!)
# ============================================
echo -e "${BOLD}${RED}❌ DEPRECATED files (MUST DELETE if found!):${NC}"
DEPRECATED_COUNT=0

OLD_FILES=$(find . \( -name "*SignalProtocol*.swift" -o -name "*DoubleRatchet*.swift" -o -name "*EncryptionService*.swift" -o -name "*EncryptionManager*.swift" \) -not -path "*/DerivedData/*" -not -path "*/.build/*" -type f 2>/dev/null)

if [ -z "$OLD_FILES" ]; then
    echo -e "  ${GREEN}✅ No deprecated files found!${NC}"
else
    echo "$OLD_FILES" | while read file; do
        echo -e "  ${RED}❌ DELETE THIS: $file${NC}"
        DEPRECATED_COUNT=$((DEPRECATED_COUNT + 1))
    done
    echo -e "  ${RED}${BOLD}⚠️  CRITICAL: Delete these files immediately!${NC}"
    ISSUES=$((ISSUES + DEPRECATED_COUNT))
fi
echo ""

# ============================================
# 7. CODE REFERENCES TO OLD ENCRYPTION
# ============================================
echo -e "${BOLD}🔍 Code references to old encryption (should be EMPTY!):${NC}"

SIGNAL_REFS=$(grep -r "SignalProtocolManager" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" 2>/dev/null | grep -v ".md" || echo "")
RATCHET_REFS=$(grep -r "DoubleRatchetManager" . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" 2>/dev/null | grep -v ".md" || echo "")
SERVICE_REFS=$(grep -r "EncryptionService\." . --include="*.swift" --exclude-dir="DerivedData" --exclude-dir=".build" 2>/dev/null | grep -v ".md" || echo "")

if [ -z "$SIGNAL_REFS" ] && [ -z "$RATCHET_REFS" ] && [ -z "$SERVICE_REFS" ]; then
    echo -e "  ${GREEN}✅ No references to old encryption found!${NC}"
else
    if [ ! -z "$SIGNAL_REFS" ]; then
        echo -e "  ${RED}❌ SignalProtocolManager references:${NC}"
        echo "$SIGNAL_REFS" | while read ref; do
            echo -e "    ${YELLOW}$ref${NC}"
        done
        ISSUES=$((ISSUES + 1))
    fi
    
    if [ ! -z "$RATCHET_REFS" ]; then
        echo -e "  ${RED}❌ DoubleRatchetManager references:${NC}"
        echo "$RATCHET_REFS" | while read ref; do
            echo -e "    ${YELLOW}$ref${NC}"
        done
        ISSUES=$((ISSUES + 1))
    fi
    
    if [ ! -z "$SERVICE_REFS" ]; then
        echo -e "  ${RED}❌ EncryptionService references:${NC}"
        echo "$SERVICE_REFS" | while read ref; do
            echo -e "    ${YELLOW}$ref${NC}"
        done
        ISSUES=$((ISSUES + 1))
    fi
    
    echo -e "  ${RED}${BOLD}⚠️  UPDATE: Replace with SimpleEncryption.shared${NC}"
fi
echo ""

# ============================================
# 8. SUMMARY
# ============================================
echo -e "${BOLD}${BLUE}============================================${NC}"
if [ $ISSUES -eq 0 ]; then
    echo -e "${BOLD}${GREEN}✅ ALL CHECKS PASSED!${NC}"
    echo -e "${GREEN}No duplicates, no deprecated files!${NC}"
    echo -e "${GREEN}Your project is clean! 🎉${NC}"
else
    echo -e "${BOLD}${YELLOW}⚠️  FOUND $ISSUES ISSUE(S)${NC}"
    echo -e "${YELLOW}Please fix the issues listed above.${NC}"
    echo ""
    echo -e "${BOLD}Actions needed:${NC}"
    echo -e "1. ${RED}DELETE${NC} deprecated encryption files"
    echo -e "2. ${RED}DELETE${NC} duplicate files (keep only 1 of each)"
    echo -e "3. ${YELLOW}UPDATE${NC} code references to use SimpleEncryption.shared"
    echo -e "4. ${GREEN}RUN${NC} this script again to verify"
fi
echo -e "${BOLD}${BLUE}============================================${NC}\n"

exit $ISSUES

#!/bin/bash
# Pre-push checklist untuk SRS-PLN-NPS (3 repo)
# Verifikasi sebelum push ke GitHub

set -e

echo "🔍 Running pre-push checklist for SRS-PLN-NPS..."
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

Errors=0
Warnings=0

# Check function
check() {
    local status=$1
    local message=$2
    
    if [ $status -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $message"
    else
        echo -e "${RED}✗${NC} $message"
        ((Errors++))
    fi
}

warn() {
    local message=$1
    echo -e "${YELLOW}⚠${NC} $message"
    ((Warnings++))
}

echo "📦 Backend Go (backend/):"
check $([ -f "backend/.env.example" ] && echo 0 || echo 1) ".env.example exists"
check $([ -f "backend/.gitignore" ] && echo 0 || echo 1) ".gitignore exists"
check $([ -f "backend/go.mod" ] && echo 0 || echo 1) "go.mod exists"
check $([ -f "backend/Dockerfile" ] && echo 0 || echo 1) "Dockerfile exists"

if [ -f "backend/.env" ]; then
    if grep -q "^\.env$" "backend/.gitignore" 2>/dev/null; then
        check 0 ".env is in .gitignore"
    else
        warn ".env exists but NOT in .gitignore!"
    fi
fi

echo ""
echo "📱 Mobile Flutter (lib/):"
check $([ -f "lib/main.dart" ] && echo 0 || echo 1) "main.dart exists"
check $([ -f "pubspec.yaml" ] && echo 0 || echo 1) "pubspec.yaml exists"
check $([ -f ".gitignore" ] && echo 0 || echo 1) ".gitignore exists (root)"

if [ -f "lib/.env" ]; then
    warn "Found lib/.env - should be .gitignored!"
fi

echo ""
echo "🌐 Admin Web Next.js (admin-web/):"
check $([ -f "admin-web/.env.example" ] && echo 0 || echo 1) ".env.example exists"
check $([ -f "admin-web/.gitignore" ] && echo 0 || echo 1) ".gitignore exists"
check $([ -f "admin-web/package.json" ] && echo 0 || echo 1) "package.json exists"
check $([ -f "admin-web/Dockerfile" ] && echo 0 || echo 1) "Dockerfile exists"

if [ -f "admin-web/.env" ]; then
    if grep -q "^\.env$" "admin-web/.gitignore" 2>/dev/null; then
        check 0 ".env is in .gitignore"
    else
        warn ".env exists but NOT in .gitignore!"
    fi
fi

echo ""
echo "═══════════════════════════════════════"

if [ $Errors -gt 0 ]; then
    echo -e "${RED}❌ Found $Errors error(s)! Fix them before pushing.${NC}"
    exit 1
elif [ $Warnings -gt 0 ]; then
    echo -e "${YELLOW}⚠ Found $Warnings warning(s). Review before pushing.${NC}"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
else
    echo -e "${GREEN}✅ All checks passed! Ready to push to 3 repos.${NC}"
fi

echo ""
echo "Run: ./push-to-repos.sh"

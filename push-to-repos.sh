#!/bin/bash
# Script untuk push folder lib/, backend/, admin-web/ ke 3 GitHub repo SRS-PLN-NPS

set -e  # Exit on error

echo "🚀 Memulai proses push ke 3 repositories SRS-PLN-NPS..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fungsi untuk push folder ke repo
push_folder() {
    local folder=$1
    local repo_url=$2
    local repo_name=$3
    local branch=$4
    
    echo -e "${BLUE}📦 Processing: $repo_name${NC}"
    echo "   Folder: $folder"
    echo "   URL: $repo_url"
    echo ""
    
    # Check if folder exists
    if [ ! -d "$folder" ]; then
        echo -e "${RED}❌ Folder $folder tidak ditemukan!${NC}"
        return 1
    fi
    
    # Save current directory
    CURRENT_DIR=$(pwd)
    
    # Create temp directory for git operations
    TEMP_DIR=$(mktemp -d)
    echo "   Temp dir: $TEMP_DIR"

    cd "$TEMP_DIR"

    # Clone the target repo so pushes stay fast-forward and never require force.
    if git clone --branch "$branch" --single-branch "$repo_url" repo 2>/dev/null; then
        echo "   Cloned existing branch $branch"
    else
        echo "   Branch $branch not found remotely, initializing new repo"
        mkdir repo
        cd repo
        git init
        git branch -M "$branch"
        git remote add origin "$repo_url"
    fi

    cd "$TEMP_DIR/repo"
    git config user.name "GitHub Actions" 2>/dev/null || git config user.name "Dev"
    git config user.email "action@github.com" 2>/dev/null || git config user.email "dev@local"

    # Copy folder contents into the repository root.
    cp -R "$CURRENT_DIR/$folder/." .

    # Add all files
    echo "   Adding files..."
    git add .

    # Commit
    echo "   Creating commit..."
    git commit -m "Update: SRS-PLN-NPS $repo_name - $(date '+%Y-%m-%d %H:%M:%S')" || {
        echo "   Nothing to commit"
        cd "$CURRENT_DIR"
        rm -rf "$TEMP_DIR"
        return 0
    }

    # Push without force; if remote moved, rebase and retry.
    echo "   Pushing to GitHub (no force)..."
    if ! git push -u origin "$branch"; then
        echo "   Push rejected, rebasing on latest remote branch..."
        git fetch origin "$branch"
        git rebase "origin/$branch" || {
            echo "   Rebase failed. Resolve conflicts manually and retry."
            cd "$CURRENT_DIR"
            rm -rf "$TEMP_DIR"
            return 1
        }
        git push -u origin "$branch"
    fi
    
    echo -e "${GREEN}✅ $repo_name berhasil di-push!${NC}"
    echo ""
    
    # Cleanup
    cd "$CURRENT_DIR"
    rm -rf "$TEMP_DIR"
}

# Confirm before pushing
echo -e "${YELLOW}⚠️  This will push to 3 repositories:${NC}"
echo "   1. lib/       → https://github.com/D4marp/SRS-PLN-NPS-mobile.git"
echo "   2. backend/   → https://github.com/D4marp/SRS-PLN-NPS_BE.git"
echo "   3. admin-web/ → https://github.com/D4marp/SRS-PLN-NPS_web.git"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Working directory: $(pwd)"
echo ""

# 1. Mobile (Flutter)
push_folder "lib" "https://github.com/D4marp/SRS-PLN-NPS-mobile.git" "Mobile Flutter" "main"

# 2. Backend (Go)
push_folder "backend" "https://github.com/D4marp/SRS-PLN-NPS_BE.git" "Backend Go" "main"

# 3. Admin Web (Next.js)
push_folder "admin-web" "https://github.com/D4marp/SRS-PLN-NPS_web.git" "Admin Web" "main"

echo -e "${GREEN}🎉 Semua 3 repository berhasil di-push!${NC}"
echo ""
echo "📍 Cek di GitHub:"
echo "   - Mobile:    https://github.com/D4marp/SRS-PLN-NPS-mobile"
echo "   - Backend:   https://github.com/D4marp/SRS-PLN-NPS_BE"
echo "   - Web Admin: https://github.com/D4marp/SRS-PLN-NPS_web"
echo ""
echo "✨ Next steps:"
echo "   1. Pastikan .env.example ada di setiap repo"
echo "   2. Update README.md dengan reference ke repo lain"
echo "   3. Setup GitHub Pages / Deployment"

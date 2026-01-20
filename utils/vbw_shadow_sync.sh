#!/bin/bash
# VBW Shadow Sync - Project-Agnostic
# Syncs current working directory to shadow location for validated execution

set -e

# Configuration
SHADOW_PATH="/tmp/vbw-shadow"
SOURCE_PATH="${1:-$PWD}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}VBW Shadow Sync${NC}"
echo "Source: $SOURCE_PATH"
echo "Target: $SHADOW_PATH"
echo ""

# Validate source exists
if [ ! -d "$SOURCE_PATH" ]; then
    echo -e "${RED}ERROR: Source directory does not exist: $SOURCE_PATH${NC}"
    exit 1
fi

# Clean previous shadow if exists
if [ -d "$SHADOW_PATH" ]; then
    echo "Cleaning previous shadow..."
    rm -rf "$SHADOW_PATH"
fi

# Create shadow directory
mkdir -p "$SHADOW_PATH"

# Rsync with common exclusions (language-agnostic)
# SECURITY: Excludes secrets, credentials, and sensitive files
echo "Syncing files..."
rsync -a --delete \
    --exclude='.git' \
    --exclude='.env' \
    --exclude='.env.*' \
    --exclude='*.env' \
    --exclude='credentials*' \
    --exclude='secrets*' \
    --exclude='*.pem' \
    --exclude='*.key' \
    --exclude='*.p12' \
    --exclude='*.pfx' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    --exclude='.venv' \
    --exclude='venv' \
    --exclude='.pytest_cache' \
    --exclude='*.pyc' \
    --exclude='*.pyo' \
    --exclude='.mypy_cache' \
    --exclude='.ruff_cache' \
    --exclude='dist' \
    --exclude='build' \
    --exclude='*.egg-info' \
    --exclude='target' \
    --exclude='.next' \
    --exclude='.nuxt' \
    --exclude='.output' \
    --exclude='coverage' \
    --exclude='.coverage' \
    --exclude='.nyc_output' \
    --exclude='.DS_Store' \
    --exclude='.idea' \
    --exclude='.vscode' \
    --exclude='*.log' \
    --exclude='vendor' \
    "$SOURCE_PATH/" "$SHADOW_PATH/"

# Initialize fresh git repo in shadow
echo "Initializing git repository..."
cd "$SHADOW_PATH"
git init -q
git add -A
git commit -q -m "VBW: Initial shadow snapshot"

# Get commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)

echo ""
echo -e "${GREEN}Shadow sync complete${NC}"
echo "Commit: $COMMIT_HASH"
echo "Files: $(git ls-files | wc -l | tr -d ' ')"
echo ""
echo "Shadow ready at: $SHADOW_PATH"

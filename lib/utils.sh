#!/bin/bash

# Utility functions for ProCare Photo Scraper

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print colored message
log() {
    local level=$1
    shift
    local msg="$@"
    case $level in
        info) echo -e "${GREEN}[INFO]${NC} $msg" ;;
        warn) echo -e "${YELLOW}[WARN]${NC} $msg" ;;
        error) echo -e "${RED}[ERROR]${NC} $msg" ;;
    esac
}

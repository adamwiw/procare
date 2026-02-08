#!/bin/bash

# ProCare Photo Scraper
# Scrapes photos from ProCare Connect API
# Usage:
#   ./procare-scraper.sh today              # Scrape today's photos (for cron)
#   ./procare-scraper.sh historical YYYY-MM-DD YYYY-MM-DD  # Scrape date range

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
AUTH_URL="${PROCARE_AUTH_URL:-https://online-auth.procareconnect.com/sessions/}"
PHOTOS_URL="${PROCARE_PHOTOS_URL:-https://api-school.procareconnect.com/api/web/parent/photos/}"
OUTPUT_DIR="${PROCARE_OUTPUT_DIR:-./photos}"

# Source library files
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/auth.sh"
source "$SCRIPT_DIR/lib/photos.sh"

# Main script
main() {
    local mode=$1
    
    # Show help if no mode specified
    if [ -z "$mode" ]; then
        echo "Usage: $0 {today|historical YYYY-MM-DD YYYY-MM-DD}"
        echo ""
        echo "Examples:"
        echo "  $0 today                                    # Scrape today's photos"
        echo "  $0 historical 2026-02-01 2026-02-07        # Scrape date range"
        exit 1
    fi
    
    case $mode in
        today)
            load_credentials
            authenticate
            scrape_today
            ;;
        historical)
            if [ $# -lt 3 ]; then
                log error "Usage: $0 historical YYYY-MM-DD YYYY-MM-DD"
                exit 1
            fi
            load_credentials
            authenticate
            scrape_historical "$2" "$3"
            ;;
        *)
            echo "Usage: $0 {today|historical YYYY-MM-DD YYYY-MM-DD}"
            echo ""
            echo "Examples:"
            echo "  $0 today                                    # Scrape today's photos"
            echo "  $0 historical 2026-02-01 2026-02-07        # Scrape date range"
            exit 1
            ;;
    esac
}

main "$@"

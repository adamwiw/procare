#!/bin/bash

# Photo fetching and downloading functions for ProCare Photo Scraper

# Fetch photos for a specific date
fetch_photos() {
    local date_from=$1
    local date_to=$2
    local page=$3
    local output_subdir=$4
    
    log info "Fetching photos for $date_from to $date_to (page $page)..."
    
    local response=$(curl -s -w "\n%{http_code}" "${PHOTOS_URL}?page=${page}&filters%5Bphoto%5D%5Bdatetime_from%5D=${date_from}%2000%3A00&filters%5Bphoto%5D%5Bdatetime_to%5D=${date_to}%2023%3A59" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json, text/plain, */*" \
        -H "Origin: https://schools.procareconnect.com" \
        -H "Referer: https://schools.procareconnect.com/")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" != "200" ]; then
        log error "Failed to fetch photos with HTTP code: $http_code"
        return 1
    fi
    
    # Create output directory
    mkdir -p "$output_subdir"
    
    # Save response for jq processing
    local json_file="$output_subdir/photos_page_${page}.json"
    echo "$body" > "$json_file"
    
    # Check if there are more pages
    local next_page=$(echo "$body" | grep -o '"next_page":[0-9]*' | cut -d':' -f2)
    
    if [ -n "$next_page" ] && [ "$next_page" != "null" ]; then
        return $next_page
    fi
    
    return 0
}

# Download a photo URL
download_photo() {
    local photo_url=$1
    local output_path=$2
    local photo_date=$3
    local photo_id=$4
    
    local filename
    
    if [ -n "$photo_date" ] && [ "$photo_date" != "null" ]; then
        # Parse date from API format: 2026-02-03T16:42:32.747-06:00
        # Format as: yyyymmdd_hhmmss.jpg
        local year=$(echo "$photo_date" | cut -dT -f1 | cut -d- -f1)
        local month=$(echo "$photo_date" | cut -dT -f1 | cut -d- -f2)
        local day=$(echo "$photo_date" | cut -dT -f1 | cut -d- -f3)
        local time=$(echo "$photo_date" | cut -dT -f2 | cut -d. -f1)
        local hour=$(echo "$time" | cut -d: -f1)
        local minute=$(echo "$time" | cut -d: -f2)
        local second=$(echo "$time" | cut -d: -f3)
        filename="${year}${month}${day}_${hour}${minute}${second}.jpg"
    elif [ -n "$photo_id" ]; then
        filename="${photo_id}.jpg"
    else
        # Fallback: extract filename from URL
        filename=$(basename "$photo_url")
        # Handle query parameters in URL
        filename=$(echo "$filename" | cut -d'?' -f1)
        
        if [ -z "$filename" ]; then
            filename="photo_$(date +%s).jpg"
        fi
    fi
    
    local full_path="$output_path/$filename"
    
    if [ -f "$full_path" ]; then
        log warn "Photo already exists: $filename"
        return 0
    fi
    
    log info "Downloading: $filename"
    curl -s -o "$full_path" "$photo_url"
}

# Process photos JSON response
process_photos() {
    local json_file=$1
    local output_dir=$2
    
    # Extract photo URLs and dates from JSON response
    # The API returns: { "photos": [ { "id": "...", "date": "...", "main_url": "..." } ] }
    # We'll use main_url for highest quality and date for filename
    
    # Check if jq is available for proper JSON parsing
    if command -v jq &> /dev/null; then
        # Use jq for proper JSON parsing
        local count=0
        while IFS= read -r line; do
            local url=$(echo "$line" | cut -d'|' -f1)
            local photo_date=$(echo "$line" | cut -d'|' -f2)
            local id=$(echo "$line" | cut -d'|' -f3)
            
            download_photo "$url" "$output_dir" "$photo_date" "$id"
            ((count++))
        done < <(jq -r '.photos[] | "\(.main_url)|\(.date // "")|\(.id)"' "$json_file")
        
        log info "Downloaded $count photo(s)"
        return
    fi
    
    # Fallback: grep-based extraction (less reliable)
    local photo_urls=$(cat "$json_file" | grep -o '"main_url":"[^"]*"' | cut -d'"' -f4)
    local photo_dates=$(cat "$json_file" | grep -o '"date":"[^"]*"' | cut -d'"' -f4)
    local photo_ids=$(cat "$json_file" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$photo_urls" ]; then
        log warn "No photo URLs found in response"
        return
    fi
    
    local count=0
    local index=0
    for url in $photo_urls; do
        local date=$(echo "$photo_dates" | sed -n "$((index + 1))p")
        local id=$(echo "$photo_ids" | sed -n "$((index + 1))p")
        download_photo "$url" "$output_dir" "$date" "$id"
        ((count++))
        ((index++))
    done
    
    log info "Downloaded $count photo(s)"
}

# Scrape photos for today
scrape_today() {
    local today=$(date +"%Y-%m-%d")
    local output_subdir="$OUTPUT_DIR/$today"
    
    log info "Scraping photos for today: $today"
    
    mkdir -p "$output_subdir"
    
    local page=1
    while true; do
        fetch_photos "$today" "$today" "$page" "$output_subdir"
        local next_page=$?
        
        process_photos "$output_subdir/photos_page_${page}.json" "$output_subdir"
        
        if [ "$next_page" -eq 0 ]; then
            break
        fi
        
        page=$next_page
    done
    
    log info "Finished scraping for $today"
}

# Scrape photos for historical date range
scrape_historical() {
    local date_from=$1
    local date_to=$2
    
    log info "Scraping photos from $date_from to $date_to"
    
    # Convert dates to seconds for iteration (macOS vs Linux compatibility)
    local current_date end_date
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        current_date=$(date -j -f "%Y-%m-%d" "$date_from" +%s)
        end_date=$(date -j -f "%Y-%m-%d" "$date_to" +%s)
    else
        # Linux
        current_date=$(date -d "$date_from" +%s)
        end_date=$(date -d "$date_to" +%s)
    fi
    
    while [ "$current_date" -le "$end_date" ]; do
        local date_str
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            date_str=$(date -r "$current_date" +"%Y-%m-%d")
        else
            # Linux
            date_str=$(date -d "@$current_date" +"%Y-%m-%d")
        fi
        local output_subdir="$OUTPUT_DIR/$date_str"
        
        log info "Processing date: $date_str"
        
        mkdir -p "$output_subdir"
        
        local page=1
        while true; do
            fetch_photos "$date_str" "$date_str" "$page" "$output_subdir"
            local next_page=$?
            
            process_photos "$output_subdir/photos_page_${page}.json" "$output_subdir"
            
            if [ "$next_page" -eq 0 ]; then
                break
            fi
            
            page=$next_page
        done
        
        # Move to next day
        current_date=$((current_date + 86400))
    done
    
    log info "Finished scraping from $date_from to $date_to"
}

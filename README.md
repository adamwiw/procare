# ProCare Photo Scraper

A bash script to scrape photos from the ProCare Connect API.

## Features

- **Authentication**: Logs in with email/password to get a bearer token
- **Two modes**:
  - `today`: Scrape photos for the current day (perfect for cron jobs)
  - `historical`: Scrape photos for a date range
- **Pagination**: Automatically handles multiple pages of results
- **Organized output**: Photos are saved in directories by date
- **Credential storage**: Saves credentials securely in `.procare_config`

## Usage

### Scrape Today's Photos

```bash
./procare-scraper.sh today
```

This is ideal for running as a cron job to automatically download new photos each day.

### Scrape Historical Date Range

```bash
./procare-scraper.sh historical YYYY-MM-DD YYYY-MM-DD
```

Example:
```bash
./procare-scraper.sh historical 2026-02-01 2026-02-07
```

## Setup

### Option 1: Environment Variables (Recommended for Docker)

Set credentials via environment variables:

```bash
export PROCARE_EMAIL="your_email@example.com"
export PROCARE_PASSWORD="your_password"
./procare-scraper.sh today
```

Or use a `.env` file (see `.env.example`):

```bash
cp .env.example .env
# Edit .env with your credentials
source .env
./procare-scraper.sh today
```

### Option 2: Config File

Run the script - it will prompt for your ProCare email and password on first run:

```bash
./procare-scraper.sh today
```

Credentials are saved to `.procare_config` (chmod 600 for security).

### Option 3: Interactive Prompt

Simply run the script without any credentials set - it will prompt you:
```bash
./procare-scraper.sh today
```

## Cron Setup

To automatically scrape photos every day, add a cron job:

```bash
# Edit crontab
crontab -e

# Add this line to run at 8 PM every day
0 20 * * * /Users/adam/Documents/GitHub/procare/procare-scraper.sh today >> /Users/adam/Documents/GitHub/procare/cron.log 2>&1
```

## Output Structure

Photos are saved in the `./photos/` directory organized by date:

```
photos/
├── 2026-02-01/
│   ├── photo_123.jpg
│   ├── photo_124.jpg
│   └── photos_page_1.json
├── 2026-02-02/
│   └── ...
└── ...
```

## Configuration

### Environment Variables

The following environment variables can be set to override defaults:

| Variable | Default | Description |
|----------|---------|-------------|
| `PROCARE_EMAIL` | - | ProCare login email |
| `PROCARE_PASSWORD` | - | ProCare login password |
| `PROCARE_AUTH_URL` | `https://online-auth.procareconnect.com/sessions/` | Authentication endpoint |
| `PROCARE_PHOTOS_URL` | `https://api-school.procareconnect.com/api/web/parent/photos/` | Photos API endpoint |
| `PROCARE_OUTPUT_DIR` | `./photos` | Where to save downloaded photos |
| `PROCARE_CONFIG_FILE` | `.procare_config` | Where to store credentials |

### Credential Priority

Credentials are loaded in this order (first found wins):
1. Environment variables (`PROCARE_EMAIL`, `PROCARE_PASSWORD`)
2. Config file (`.procare_config`)
3. Interactive prompt

## Docker Usage

### Build the Docker image

```bash
docker build -t procare-scraper .
```

### Run with Docker

**Using environment variables:**

```bash
docker run --rm \
  -v $(pwd)/photos:/app/photos \
  -e PROCARE_EMAIL="your_email@example.com" \
  -e PROCARE_PASSWORD="your_password" \
  procare-scraper \
  /app/procare-scraper.sh today
```

**Using config file:**

```bash
docker run --rm \
  -v $(pwd)/photos:/app/photos \
  -v $(pwd)/.procare_config:/app/.procare_config \
  procare-scraper \
  /app/procare-scraper.sh today
```

**Scrape historical date range (with env vars):**

```bash
docker run --rm \
  -v $(pwd)/photos:/app/photos \
  -e PROCARE_EMAIL="your_email@example.com" \
  -e PROCARE_PASSWORD="your_password" \
  procare-scraper \
  /app/procare-scraper.sh historical 2026-02-01 2026-02-07
```

**Interactive shell:**

```bash
docker run -it --rm \
  -v $(pwd)/photos:/app/photos \
  -v $(pwd)/.procare_config:/app/.procare_config \
  procare-scraper \
  /bin/bash
```

### Docker Compose

A `docker-compose.yml` file is included for easier management.

**Using .env file (recommended):**

```bash
# Copy and edit the .env file
cp .env.example .env
# Add your credentials to .env

# Run with docker-compose
docker-compose run --rm scraper
```

**Passing environment variables directly:**

```bash
PROCARE_EMAIL="your_email@example.com" \
PROCARE_PASSWORD="your_password" \
docker-compose run --rm scraper
```

**Scrape historical date range:**

```bash
docker-compose run --rm scraper /app/procare-scraper.sh historical 2026-02-01 2026-02-07
```

**Interactive shell:**

```bash
docker run -it --rm \
  -v $(pwd)/photos:/app/photos \
  -v $(pwd)/.procare_config:/app/.procare_config \
  procare-scraper \
  /bin/bash
```

## Requirements

- `curl` (usually pre-installed on macOS/Linux)
- `jq` (recommended for proper JSON parsing and caption-based filenames)
  - macOS: `brew install jq`
  - Linux: `sudo apt-get install jq` or `sudo yum install jq`
- Docker (optional, for containerized execution - includes jq)

## Troubleshooting

### Authentication fails

Check that your email and password are correct in `.procare_config`.

### No photos downloaded

1. Check the JSON response files in the photo directories
2. The API response structure may have changed - you may need to update the `process_photos()` function to match the actual response format

### Token extraction fails

The script tries multiple patterns to extract the token. If it fails, check the actual response from the login endpoint and update the extraction logic.

## API Endpoints

Based on network capture:

- **Login**: `POST https://online-auth.procareconnect.com/sessions/`
- **Photos**: `GET https://api-school.procareconnect.com/api/web/parent/photos/`

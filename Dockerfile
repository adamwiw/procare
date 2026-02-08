FROM alpine:latest

# Install curl, bash, and jq for JSON parsing
RUN apk add --no-cache curl bash jq

# Create app directory
WORKDIR /app

# Copy the scraper script and library
COPY procare-scraper.sh /app/procare-scraper.sh
COPY lib/ /app/lib/

# Make scripts executable
RUN chmod +x /app/procare-scraper.sh /app/lib/*.sh

# Create output directory for photos
RUN mkdir -p /app/photos

# Environment variables (can be overridden at runtime)
ENV PROCARE_AUTH_URL=https://online-auth.procareconnect.com/sessions/
ENV PROCARE_PHOTOS_URL=https://api-school.procareconnect.com/api/web/parent/photos/
ENV PROCARE_OUTPUT_DIR=/app/photos
ENV PROCARE_CONFIG_FILE=/app/.procare_config

# Set default command
CMD ["/bin/bash"]

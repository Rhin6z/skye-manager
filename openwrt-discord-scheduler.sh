#!/bin/ash

# =============================================================================
# OpenWRT Discord Scheduler for Rhin6z/skye-manager
# Triggers GitHub workflow at precise WIB times to avoid GitHub Actions delays
# =============================================================================

# CONFIGURATION - GANTI SESUAI REPO KAMU
GITHUB_TOKEN="YOUR_GITHUB_TOKEN_HERE"  # Ganti dengan token kamu
GITHUB_REPO="Rhin6z/skye-manager"
WORKFLOW_FILE="ai-greeting-v2.yml"
API_URL="https://api.github.com/repos/${GITHUB_REPO}/actions/workflows/${WORKFLOW_FILE}/dispatches"

# Optional: Discord webhook untuk monitoring (opsional)
DISCORD_WEBHOOK_URL=""  # Kosongkan jika ga mau monitoring

# LOGGING SETUP
LOG_FILE="/tmp/discord-scheduler.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S WIB')

# FUNCTIONS
log_message() {
    echo "[${TIMESTAMP}] $1" >> "$LOG_FILE"
    echo "[${TIMESTAMP}] $1"
}

# Function to trigger GitHub workflow
trigger_workflow() {
    local time_type="$1"
    
    log_message "🚀 Triggering ${time_type} greeting workflow..."
    
    # GitHub API call to dispatch workflow
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/github_response.json \
        -X POST \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -d "{\"ref\":\"main\",\"inputs\":{\"trigger_source\":\"openwrt_${time_type}\",\"scheduled_time\":\"${TIMESTAMP}\"}}" \
        "$API_URL")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -c 4)
    
    if [ "$HTTP_CODE" = "204" ]; then
        log_message "✅ ${time_type} workflow triggered successfully (HTTP: ${HTTP_CODE})"
        
        # Optional: Send success notification to Discord
        if [ -n "$DISCORD_WEBHOOK_URL" ]; then
            curl -s -X POST "$DISCORD_WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"content\":\"🤖 **OpenWRT Scheduler** - ${time_type} greeting triggered at ${TIMESTAMP}\"}" \
                > /dev/null 2>&1
        fi
    else
        log_message "❌ ${time_type} workflow FAILED (HTTP: ${HTTP_CODE})"
        log_message "Response: $(cat /tmp/github_response.json 2>/dev/null || echo 'No response')"
        
        # Optional: Send error notification to Discord
        if [ -n "$DISCORD_WEBHOOK_URL" ]; then
            curl -s -X POST "$DISCORD_WEBHOOK_URL" \
                -H "Content-Type: application/json" \
                -d "{\"content\":\"🚨 **OpenWRT Scheduler ERROR** - ${time_type} failed (HTTP: ${HTTP_CODE}) at ${TIMESTAMP}\"}" \
                > /dev/null 2>&1
        fi
    fi
    
    # Cleanup temp file
    rm -f /tmp/github_response.json
}

# MAIN LOGIC - Determine time type based on current hour (WIB)
CURRENT_HOUR=$(date '+%H')
CURRENT_DAY=$(date '+%u')  # 1=Monday, 7=Sunday

log_message "📅 Current time: ${CURRENT_HOUR}:$(date '+%M') WIB (Day: ${CURRENT_DAY})"

case $CURRENT_HOUR in
    06) 
        log_message "🌅 Morning time detected"
        trigger_workflow "morning" 
        ;;
    12) 
        log_message "☀️ Afternoon time detected"
        trigger_workflow "afternoon" 
        ;;
    18) 
        log_message "🌆 Evening time detected"
        trigger_workflow "evening" 
        ;;
    23) 
        log_message "🌙 Night time detected"
        trigger_workflow "night" 
        ;;
    *) 
        log_message "⏰ Not a scheduled time (${CURRENT_HOUR}:xx WIB) - skipping"
        exit 0
        ;;
esac

log_message "🏁 Scheduler run completed"

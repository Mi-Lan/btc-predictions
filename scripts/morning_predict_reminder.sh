#!/usr/bin/env bash
#
# morning_predict_reminder.sh — Called by the 10:00 AM cron job.
# Sends a reminder to Telegram asking Milan for Higher or Lower prediction.
# Writes today's prediction placeholder (null) so the snapshot job can fill it later.
#
set -euo pipefail

REPO_DIR="/root/btc-predictions"
DATA_DIR="$REPO_DIR/data"
PREDICTION_FILE="$DATA_DIR/today_prediction.json"

mkdir -p "$DATA_DIR"

CURRENT_PRICE=$(cat "$DATA_DIR/last_price.txt" 2>/dev/null || echo "N/A")
TODAY=$(date '+%Y-%m-%d')

# --- GUARD: never clobber a prediction already locked in for today ---
# Without this, re-running the reminder (or the 8AM cron firing after an early
# manual prediction) wipes the user's answer and the nightly snapshot finds
# nothing to score. Bug hit 2026-07-25.
if [ -f "$PREDICTION_FILE" ]; then
    EXISTING_DATE=$(python3 -c "import json;print(json.load(open('$PREDICTION_FILE')).get('date',''))" 2>/dev/null || echo "")
    EXISTING_PRED=$(python3 -c "import json;print(json.load(open('$PREDICTION_FILE')).get('prediction',''))" 2>/dev/null || echo "")
    if [ "$EXISTING_DATE" = "$TODAY" ] && [ -n "$EXISTING_PRED" ]; then
        echo "===MORNING_REMINDER==="
        echo "DATE: $TODAY"
        echo "LAST_PRICE: $CURRENT_PRICE"
        echo "ALREADY_PREDICTED: $EXISTING_PRED"
        echo "NOTE: Prediction already locked in for today — file left untouched."
        exit 0
    fi
fi

# Initialize empty prediction file — will be filled when user replies
cat > "$PREDICTION_FILE" <<EOF
{
  "date": "${TODAY}",
  "prediction": "",
  "timestamp": "$(python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).isoformat(timespec='seconds'))")",
  "morning_price_reference": "${CURRENT_PRICE}"
}
EOF

cd "$REPO_DIR"
git add "$PREDICTION_FILE"
git commit -m "🌅 Morning Prediction Reminder ${TODAY} — awaiting Higher/Lower input

Reference price (last known): \$${CURRENT_PRICE}
Awaiting prediction input from user.
" 2>&1

git push origin main 2>&1 || git push origin master 2>&1 || true

echo "===MORNING_REMINDER==="
echo "DATE: $TODAY"
echo "LAST_PRICE: $CURRENT_PRICE"

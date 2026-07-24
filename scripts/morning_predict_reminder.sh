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

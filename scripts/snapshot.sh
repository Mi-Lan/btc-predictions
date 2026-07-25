#!/usr/bin/env bash
#
# snapshot.sh — Fetch the exact Bitcoin price and append it to the daily log.
#              Also compares against yesterday's closing price to evaluate
#              the morning prediction (higher/lower) and updates the scoreboard.
#
# Usage: ./snapshot.sh
#
# Reads:
#   data/today_prediction.json   — written by the morning reminder job
#   data/btc_prices.csv          — historical prices
# Writes:
#   data/btc_prices.csv          — appended row
#   data/scoreboard.csv          — appended/confirmed row if prediction exists
#   data/last_price.txt          — latest price for quick reference
#
set -euo pipefail

REPO_DIR="/root/btc-predictions"
DATA_DIR="$REPO_DIR/data"
PRICES_CSV="$DATA_DIR/btc_prices.csv"
SCOREBOARD_CSV="$DATA_DIR/scoreboard.csv"
PREDICTION_FILE="$DATA_DIR/today_prediction.json"
LAST_PRICE="$DATA_DIR/last_price.txt"

mkdir -p "$DATA_DIR"

# --- Fetch BTC price from CoinGecko (free, no API key) ---
PRICE=$(curl -sf "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd&include_last_updated_at=true" \
    | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"{d['bitcoin']['usd']:.2f}\")" 2>/dev/null)

if [ -z "$PRICE" ] || [ "$PRICE" = "null" ]; then
    echo "ERROR: Failed to fetch BTC price"
    exit 1
fi

TIMESTAMP=$(python3 -c "from datetime import datetime,timezone; print(datetime.now(timezone.utc).isoformat(timespec='seconds'))")
LOCAL_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')
TODAY=$(date '+%Y-%m-%d')

# --- Log to prices CSV ---
if [ ! -f "$PRICES_CSV" ]; then
    echo "date,price_usd,fetched_at_utc" > "$PRICES_CSV"
fi
echo "${TODAY},${PRICE},${TIMESTAMP}" >> "$PRICES_CSV"
echo "$PRICE" > "$LAST_PRICE"

# --- Evaluate today's prediction if it exists ---
EVAL_RESULT=""
PREDICTION=""
ACTUAL_MOVE=""

if [ -f "$PREDICTION_FILE" ]; then
    # --- GUARD: never score the same date twice ---
    # The scoreboard is append-only. Without this, a re-run (manual, retry, or
    # a cron firing twice due to a timezone change) adds a duplicate row and
    # inflates the win/loss record. Bug caught 2026-07-26.
    if [ -f "$SCOREBOARD_CSV" ] && grep -q "^${TODAY}," "$SCOREBOARD_CSV" 2>/dev/null; then
        echo "===SNAPSHOT==="
        echo "PRICE: $PRICE"
        echo "DATE: $TODAY"
        echo "EVAL: ALREADY_SCORED"
        echo "TIME: ${LOCAL_TIME}"
        echo "NOTE: ${TODAY} already scored — scoreboard left untouched."
        cd "$REPO_DIR"
        git add "$PRICES_CSV" "$LAST_PRICE" 2>/dev/null || true
        git commit -m "📊 BTC price log ${TODAY}: \$${PRICE} @ ${LOCAL_TIME} (already scored)" 2>&1 || true
        git push origin main 2>&1 || git push origin master 2>&1 || true
        exit 0
    fi

    PREDICTION=$(python3 -c "import json; d=json.load(open('$PREDICTION_FILE')); print(d.get('prediction',''))" 2>/dev/null || echo "")
    PREDICTION_TS=$(python3 -c "import json; d=json.load(open('$PREDICTION_FILE')); print(d.get('prediction_submitted_at_utc', d.get('timestamp','')))" 2>/dev/null || echo "")
    # Use the price captured at prediction time — NOT yesterday's price
    PRED_PRICE=$(python3 -c "import json; d=json.load(open('$PREDICTION_FILE')); print(d.get('prediction_price_usd',''))" 2>/dev/null || echo "")

    if [ -n "$PREDICTION" ] && [ -n "$PRED_PRICE" ] && [ "$PRED_PRICE" != "N/A" ] && [ "$PRED_PRICE" != "" ]; then
        ACTUAL_MOVE=$(python3 -c "print('higher' if float('$PRICE') > float('$PRED_PRICE') else 'lower')")
        CORRECT="false"
        if [ "$PREDICTION" = "$ACTUAL_MOVE" ]; then
            CORRECT="true"
        fi
        EVAL_RESULT="${PREDICTION}|${ACTUAL_MOVE}|${CORRECT}"

        # Append to scoreboard
        if [ ! -f "$SCOREBOARD_CSV" ]; then
            echo "date,predicted,actual,correct,prediction_time_utc,prediction_price_usd,snapshot_price_usd" > "$SCOREBOARD_CSV"
        fi
        echo "${TODAY},${PREDICTION},${ACTUAL_MOVE},${CORRECT},${PREDICTION_TS},${PRED_PRICE},${PRICE}" >> "$SCOREBOARD_CSV"

        # Calculate win rate
        WIN_RATE=$(python3 -c "
import csv
rows = list(csv.DictReader(open('$SCOREBOARD_CSV')))
wins = sum(1 for r in rows if r['correct'] == 'true')
total = len(rows)
print(f'{wins}/{total}' if total > 0 else '0/0')
" 2>/dev/null || echo "0/0")

        echo "PREDICTION_EVALUATED: predicted=${PREDICTION}, prediction_price=${PRED_PRICE}, snapshot_price=${PRICE}, actual=${ACTUAL_MOVE}, correct=${CORRECT}, record=${WIN_RATE}"
    else
        EVAL_RESULT="NO_PREDICTION_PRICE"
        echo "WARNING: Could not compare — no prediction price found in prediction file"
    fi
else
    echo "INFO: No prediction file found for today — logging price only"
fi

# --- Commit to GitHub ---
cd "$REPO_DIR"
git add "$PRICES_CSV" "$LAST_PRICE" "$SCOREBOARD_CSV" 2>/dev/null || true
git commit -m "📊 BTC Price Snapshot ${TODAY}: \$${PRICE} @ ${LOCAL_TIME}

Predicted: ${PREDICTION:-N/A}
Actual move: ${ACTUAL_MOVE:-N/A}
Correct: ${EVAL_RESULT:-N/A}

UTC: ${TIMESTAMP}" 2>&1

git push origin main 2>&1 || git push origin master 2>&1 || true

# --- Output for Telegram delivery ---
echo "===SNAPSHOT==="
echo "PRICE: $PRICE"
echo "DATE: $TODAY"
echo "EVAL: ${EVAL_RESULT:-NONE}"
echo "TIME: ${LOCAL_TIME}"

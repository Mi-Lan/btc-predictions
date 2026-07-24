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
    PREDICTION=$(python3 -c "import json; d=json.load(open('$PREDICTION_FILE')); print(d.get('prediction',''))" 2>/dev/null || echo "")
    PREDICTION_TS=$(python3 -c "import json; d=json.load(open('$PREDICTION_FILE')); print(d.get('timestamp',''))" 2>/dev/null || echo "")
    PREV_PRICE=$(python3 -c "
import csv
rows = list(csv.reader(open('$PRICES_CSV')))
if len(rows) > 2:
    print(rows[-2][1])
elif len(rows) > 1:
    print(rows[-1][1])
else:
    print('0')
" 2>/dev/null || echo "0")

    if [ -n "$PREDICTION" ] && [ "$PREV_PRICE" != "0" ] && [ -n "$PREV_PRICE" ]; then
        ACTUAL_MOVE=$(python3 -c "print('higher' if float('$PRICE') > float('$PREV_PRICE') else 'lower')")
        CORRECT="false"
        if [ "$PREDICTION" = "$ACTUAL_MOVE" ]; then
            CORRECT="true"
        fi
        EVAL_RESULT="${PREDICTION}|${ACTUAL_MOVE}|${CORRECT}"

        # Append to scoreboard
        if [ ! -f "$SCOREBOARD_CSV" ]; then
            echo "date,predicted,actual,correct,prediction_time_utc,price_snapshot_usd" > "$SCOREBOARD_CSV"
        fi
        echo "${TODAY},${PREDICTION},${ACTUAL_MOVE},${CORRECT},${PREDICTION_TS},${PRICE}" >> "$SCOREBOARD_CSV"

        # Calculate win rate
        WIN_RATE=$(python3 -c "
import csv
rows = list(csv.DictReader(open('$SCOREBOARD_CSV')))
wins = sum(1 for r in rows if r['correct'] == 'true')
total = len(rows)
print(f'{wins}/{total}' if total > 0 else '0/0')
" 2>/dev/null || echo "0/0")

        echo "PREDICTION_EVALUATED: predicted=${PREDICTION}, actual=${ACTUAL_MOVE}, correct=${CORRECT}, record=${WIN_RATE}"
    else
        EVAL_RESULT="NO_PREV_PRICE"
        echo "WARNING: Could not compare — no previous price found"
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

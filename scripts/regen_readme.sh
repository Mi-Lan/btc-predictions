#!/usr/bin/env bash
#
# regen_readme.sh — Regenerate README.md scoreboard table from scoreboard.csv.
# Single source of truth for README generation. Called by snapshot.sh on both
# the fresh-score path AND the already-scored re-run path so the README never
# falls behind the CSV. Safe to run standalone.
#
set -euo pipefail

REPO_DIR="/root/btc-predictions"
SCOREBOARD_CSV="$REPO_DIR/data/scoreboard.csv"

[ -f "$SCOREBOARD_CSV" ] || { echo "No scoreboard yet — nothing to regen."; exit 0; }

cd "$REPO_DIR"
python3 -c "
import csv
rows = list(csv.DictReader(open('$SCOREBOARD_CSV')))
wins = sum(1 for r in rows if r['correct'] == 'true')
losses = sum(1 for r in rows if r['correct'] == 'false')
total = len(rows)
record = f'{wins}-{losses}' if total > 0 else '0-0'
rate = f'{(wins/total*100):.0f}%' if total > 0 else '-'

table_rows = ''
for r in rows:
    date = r['date']
    pred = r['predicted'].upper()
    actual = r['actual'].upper()
    correct = '✅' if r['correct'] == 'true' else '❌'
    snap_price = f\"\${float(r['snapshot_price_usd']):,.2f}\"
    table_rows += f'| {date} | {pred} | {actual} | {correct} | {snap_price} |\n'

readme = f'''# ₿ BTC Daily Predictions Scoreboard

Automated Bitcoin price tracking and prediction game. Every day:

1. **10:00 AM** — Morning reminder: tap ☀️ Sun (higher) or 🌙 Moon (lower)
2. **23:11** — Bitcoin price is fetched, logged, and your prediction is evaluated
3. **Scoreboard updated** — win/loss record committed to this repo

## Current Score

**Record: {record}** | **Win Rate: {rate}**

| Date | Predicted | Actual | Correct | Snapshot Price |
|------|-----------|--------|---------|-----------------|
{table_rows}## How It Works

- **Prediction**: Tap ☀️ Sun (higher) or 🌙 Moon (lower) on the 10 AM Telegram reminder
- **Price source**: CoinGecko API (real-time BTC/USD)
- **Comparison**: Today's prediction price vs tonight's 23:11 snapshot price
- **Scoring**: Your prediction is marked correct if it matches the actual price movement

## Files

- \`data/btc_prices.csv\` — Daily price snapshots
- \`data/scoreboard.csv\` — Prediction accuracy record
- \`data/today_prediction.json\` — Today's prediction (waiting for input)
- \`data/last_price.txt\` — Most recent BTC price
- \`scripts/snapshot.sh\` — Price fetch + evaluation engine
- \`scripts/morning_predict_reminder.sh\` — Morning reminder trigger
- \`scripts/regen_readme.sh\` — README scoreboard regenerator
- \`scripts/save_prediction.py\` — Saves your prediction to repo

---

*Automated by Hermes Agent · Powered by CoinGecko API*
'''
open('README.md', 'w').write(readme)
print('README updated — record', record, 'rate', rate)
"

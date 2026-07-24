# ₿ BTC Daily Predictions Scoreboard

Automated Bitcoin price tracking and prediction game. Every day:

1. **10:00 AM** — Morning reminder: predict if BTC will be **higher** or **lower** by 23:11
2. **23:11** — Bitcoin price is fetched, logged, and your prediction is evaluated
3. **Scoreboard updated** — win/loss record committed to this repo

## Current Score

| Date | Predicted | Actual | Correct | Price (UTC) |
|------|-----------|--------|---------|-------------|

*(Populated automatically — see `data/scoreboard.csv` for raw data)*

## How It Works

- **Prediction**: Reply "higher" or "lower" to the 10 AM Telegram reminder
- **Price source**: CoinGecko API (real-time BTC/USD)
- **Comparison**: Today's 23:11 price vs yesterday's 23:11 price
- **Scoring**: Your prediction is marked correct if it matches the actual price movement

## Files

- `data/btc_prices.csv` — Daily price snapshots
- `data/scoreboard.csv` — Prediction accuracy record
- `data/today_prediction.json` — Today's prediction (waiting for input)
- `data/last_price.txt` — Most recent BTC price
- `scripts/snapshot.sh` — Price fetch + evaluation engine
- `scripts/morning_predict_reminder.sh` — Morning reminder trigger
- `scripts/save_prediction.py` — Saves your prediction to repo

---

*Automated by Hermes Agent · Powered by CoinGecko API*

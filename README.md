# ₿ BTC Daily Predictions Scoreboard

Automated Bitcoin price tracking and prediction game. Every day:

1. **10:00 AM** — Morning reminder: tap ☀️ Sun (higher) or 🌙 Moon (lower)
2. **23:11** — Bitcoin price is fetched, logged, and your prediction is evaluated
3. **Scoreboard updated** — win/loss record committed to this repo

## Current Score

**Record: 4-1** | **Win Rate: 80%**

| Date | Predicted | Actual | Correct | Snapshot Price |
|------|-----------|--------|---------|-----------------|
| 2026-07-25 | HIGHER | HIGHER | ✅ | $64,312.00 |
| 2026-07-26 | HIGHER | HIGHER | ✅ | $64,783.00 |
| 2026-07-27 | LOWER | LOWER | ✅ | $64,783.00 |
| 2026-07-28 | LOWER | HIGHER | ❌ | $63,818.00 |
| 2026-07-30 | HIGHER | HIGHER | ✅ | $64,734.00 |
## How It Works

- **Prediction**: Tap ☀️ Sun (higher) or 🌙 Moon (lower) on the 10 AM Telegram reminder
- **Price source**: CoinGecko API (real-time BTC/USD)
- **Comparison**: Today's prediction price vs tonight's 23:11 snapshot price
- **Scoring**: Your prediction is marked correct if it matches the actual price movement

## Files

- `data/btc_prices.csv` — Daily price snapshots
- `data/scoreboard.csv` — Prediction accuracy record
- `data/today_prediction.json` — Today's prediction (waiting for input)
- `data/last_price.txt` — Most recent BTC price
- `scripts/snapshot.sh` — Price fetch + evaluation engine
- `scripts/morning_predict_reminder.sh` — Morning reminder trigger
- `scripts/regen_readme.sh` — README scoreboard regenerator
- `scripts/save_prediction.py` — Saves your prediction to repo

---

*Automated by Hermes Agent · Powered by CoinGecko API*

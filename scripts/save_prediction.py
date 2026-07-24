#!/usr/bin/env python3
"""
save_prediction.py — Save Milan's Higher/Lower prediction to the repo and commit.
Called when Milan replies to the morning reminder with "higher" or "lower".

Usage: python3 save_prediction.py <higher|lower>
"""
import json
import sys
import subprocess
from datetime import datetime, timezone
from pathlib import Path

REPO_DIR = Path("/root/btc-predictions")
DATA_DIR = REPO_DIR / "data"
PREDICTION_FILE = DATA_DIR / "today_prediction.json"

def main():
    if len(sys.argv) < 2:
        print("ERROR: No prediction provided. Usage: save_prediction.py <higher|lower>")
        sys.exit(1)

    prediction = sys.argv[1].lower().strip()
    if prediction not in ("higher", "lower"):
        print(f"ERROR: Invalid prediction '{prediction}'. Must be 'higher' or 'lower'.")
        sys.exit(1)

    DATA_DIR.mkdir(parents=True, exist_ok=True)

    now_utc = datetime.now(timezone.utc).isoformat(timespec="seconds")
    today = datetime.now().strftime("%Y-%m-%d")

    # Read existing file if it exists (preserve morning timestamp)
    morning_ts = now_utc
    morning_ref = "N/A"
    if PREDICTION_FILE.exists():
        try:
            existing = json.loads(PREDICTION_FILE.read_text())
            morning_ts = existing.get("timestamp", now_utc)
            morning_ref = existing.get("morning_price_reference", "N/A")
        except Exception:
            pass

    data = {
        "date": today,
        "prediction": prediction,
        "timestamp": morning_ts,
        "prediction_submitted_at_utc": now_utc,
        "morning_price_reference": morning_ref,
    }

    PREDICTION_FILE.write_text(json.dumps(data, indent=2) + "\n")

    # Commit and push
    subprocess.run(["git", "add", str(PREDICTION_FILE)], cwd=REPO_DIR, check=True)
    commit_msg = f"🎯 Prediction {today}: {prediction.upper()} (submitted {now_utc})"
    subprocess.run(["git", "commit", "-m", commit_msg], cwd=REPO_DIR, check=True)

    # Try pushing
    push = subprocess.run(["git", "push", "origin", "main"], cwd=REPO_DIR, capture_output=True, text=True)
    if push.returncode != 0:
        subprocess.run(["git", "push", "origin", "master"], cwd=REPO_DIR, capture_output=True, text=True)

    print(f"===PREDICTION_SAVED===")
    print(f"DATE: {today}")
    print(f"PREDICTION: {prediction}")
    print(f"TIMESTAMP: {now_utc}")

if __name__ == "__main__":
    main()

#!/bin/bash
set -euo pipefail

LOG_FILE="monitor.log"
INTERVAL=600  # Interval between logs in seconds

if [ -f "$LOG_FILE" ]; then
  echo "Log file $LOG_FILE already exists. Please remove or rename it before running this script."
  rm "$LOG_FILE"
fi

# ------------------------------------------------------------
# Start the monitoring process in the background.
# It runs in its own subshell so we can later kill the whole group.
# ------------------------------------------------------------
(
  while true; do
    {
      echo "===== $(date '+%Y-%m-%d %H:%M:%S') ====="
      top -b -n1 | head -20          # Capture top 20 processes
      nvidia-smi                     # GPU usage
      echo
    } >> "$LOG_FILE"
    sleep "$INTERVAL"
  done
) &
MONITOR_PID=$!

# Get the process group ID of the monitor (usually equal to its PID).
MONITOR_PGID=$(ps -o pgid= "$MONITOR_PID" | tr -d ' ')

# ------------------------------------------------------------
# Cleanup function:
# - Ensures the monitoring process is killed when Python exits
# - Sends SIGTERM to the entire process group (monitor loop + sleep/top/nvidia-smi)
# - If needed, escalates to SIGKILL
# ------------------------------------------------------------
cleanup() {
  if kill -0 "$MONITOR_PID" 2>/dev/null; then
    echo "Stopping monitor (PGID=$MONITOR_PGID, PID=$MONITOR_PID)..."
    kill -TERM -"$MONITOR_PGID" 2>/dev/null || true
    sleep 0.5
    kill -KILL -"$MONITOR_PGID" 2>/dev/null || true
  fi
}

# Run cleanup() when the script exits or receives INT/TERM
trap cleanup EXIT INT TERM

# ------------------------------------------------------------
# Run the training script in the foreground.
# Once it finishes (successfully or with error),
# the trap will trigger cleanup() and stop the monitor.
# ------------------------------------------------------------
python scripts/gr00t_finetune.py \
  --dataset-path ./demo_data/Pick-Green-Cube-u101/ \
  --num-gpus 1 \
  --output-dir ./so101-checkpoints-Pick-Green-Cube-u101/  \
  --max-steps 10000 \
  --save_steps 10000 \
  --data-config so100_dualcam \
  --video-backend torchvision_av

mv monitor.log monitor-Pick-Green-Cube-u101.log

python scripts/gr00t_finetune.py \
  --dataset-path ./demo_data/Pick-Green-Cube-20251110-u101/ \
  --num-gpus 1 \
  --output-dir ./so101-checkpoints-Pick-Green-Cube-20251110-u101/  \
  --max-steps 10000 \
  --save_steps 10000 \
  --data-config so100_dualcam \
  --video-backend torchvision_av

# 4aef896439a13a43983cd4a69cb87718eb5715cd
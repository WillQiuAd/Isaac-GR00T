#/bin/bash
set -Eeuo pipefail

# ===================================================
# Global Variables
SERVER_DOCKER_NAME="${SERVER_DOCKER_NAME:-isaac-gr00t-server}"
SERVER_IMAGE_NAME="${SERVER_IMAGE_NAME:-advigw/${SERVER_DOCKER_NAME}:thor-dev}"
WORKSPACE="${WORKSPACE:-/workspace}"

# Infer parameters
MODEL_PATH="${MODEL_PATH:-so101-checkpoints-Pick-Green-Cube-u101/best-train-loss}"
EMBODIMENT_TAG="${EMBODIMENT_TAG:-new_embodiment}"
DATA_CONFIG="${DATA_CONFIG:-so100_dualcam}"
DENOISING_STEPS="${DENOISING_STEPS:-4}"

# Robot settings
ROBOT_TYPE="${ROBOT_TYPE:-so101_follower}"

# GPU settings
DOCKER_GPU_ARGS+=(--runtime nvidia -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video,graphics --device /dev/nvhost-vic)

# ===================================================
# Utilities
log() { printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }
die() { log "ERROR: $*"; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Common Docker arguments
COMMON_DOCKER_ARGS=(
  --privileged
  --rm
  -it
  --net=host
  --ipc=host
  -e "DISPLAY=${DISPLAY:-}"
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw
  -v /etc/X11:/etc/X11:ro
  -v /dev:/dev
  -v /etc/localtime:/etc/localtime:ro
  -v /var/run/docker.sock:/var/run/docker.sock
  -w "${WORKSPACE}"
)

# Cleanup function to stop containers on exit
cleanup() {
  log "Stopping containers…"
  docker stop "${SERVER_DOCKER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Stop existing containers if running
docker ps -a --format '{{.Names}}' | grep -q "^${SERVER_DOCKER_NAME}$" && docker stop "${SERVER_DOCKER_NAME}" || true

# ===================================================
# SERVER COMMAND
SERVER_CMD=(
  bash -lc
  "python scripts/inference_service.py --server \
    --model_path '${MODEL_PATH}' \
    --embodiment-tag '${EMBODIMENT_TAG}' \
    --data-config '${DATA_CONFIG}' \
    --denoising-steps ${DENOISING_STEPS}"
)

# SERVER_CMD=(
#   bash -lc
#   "python scripts/inference_service.py --server \
#     --model_path '${MODEL_PATH}' \
#     --embodiment-tag '${EMBODIMENT_TAG}' \
#     --data-config '${DATA_CONFIG}' \
#     --trt-engine-path gr00t_engine \
#     --denoising-steps ${DENOISING_STEPS} \
#     --use-tensorrt \
#     --llm-dtype nvfp4 \
#     --vit-dtype fp8 \
#     --dit-dtype fp8"
# )

cmd=$(printf '%q ' docker run --name "${SERVER_DOCKER_NAME}" \
  "${DOCKER_GPU_ARGS[@]}" \
  "${COMMON_DOCKER_ARGS[@]}" \
  -v "${script_dir}:${WORKSPACE}:rw" \
  "${SERVER_IMAGE_NAME}" \
  "${SERVER_CMD[@]}")

echo "------------------------------------------------------------"
echo "[RUN] $cmd"
echo "------------------------------------------------------------"

# Run server container
eval "$cmd"

log "Server container launched."

echo "------------------------------------------------------------"
log "Follow logs with:"
log "  docker logs -f ${SERVER_DOCKER_NAME}"
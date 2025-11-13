#/bin/bash
set -Eeuo pipefail

# ===================================================
# Global Variables
CLIENT_DOCKER_NAME="${CLIENT_DOCKER_NAME:-isaac-gr00t-thor-client}"
CLIENT_IMAGE_NAME="${CLIENT_IMAGE_NAME:-${CLIENT_DOCKER_NAME}:dev}"
WORKSPACE="${WORKSPACE:-/workspace}"

# Infer parameters
DATA_CONFIG="${DATA_CONFIG:-so100_dualcam}"

# Robot / Camera settings
ROBOT_TYPE="${ROBOT_TYPE:-so101_follower}"
ROBOT_PORT="${ROBOT_PORT:-/dev/ttyACM0}"
ROBOT_ID="${ROBOT_ID:-my_awesome_follower_arm}"

# Camera parameters
FRONT_CAM_INDEX="${FRONT_CAM_INDEX:-0}"
WRIST_CAM_INDEX="${WRIST_CAM_INDEX:-2}"
CAM_WIDTH="${CAM_WIDTH:-640}"
CAM_HEIGHT="${CAM_HEIGHT:-480}"
CAM_FPS="${CAM_FPS:-30}"

# Language instruction
LANG_INSTRUCTION="${LANG_INSTRUCTION:-Grab the pen and put it in the box}"

# HF cache paths
CALIB_DIR_CONT="${CALIB_DIR_CONT:-$WORKSPACE/.cache/huggingface/lerobot/calibration/robots/so101_follower}"

# Xhost permission
ALLOW_XHOST="${ALLOW_XHOST:-1}"

# GPU settings
DOCKER_GPU_ARGS+=(--runtime nvidia -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video,graphics --device /dev/nvhost-vic)

# ===================================================
# Utilities
log() { printf "[%s] %s\n" "$(date +'%F %T')" "$*"; }
die() { log "ERROR: $*"; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"

# Setup Xhost permission
if [[ "${ALLOW_XHOST}" == "1" && -n "${DISPLAY:-}" && -x "$(command -v xhost)" ]]; then
  # Allow local user to access X server
  xhost +SI:localuser:"${USER}" >/dev/null 2>&1 || true
fi

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
  docker stop "${CLIENT_DOCKER_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Stop existing containers if running
docker ps -a --format '{{.Names}}' | grep -q "^${CLIENT_DOCKER_NAME}$" && docker stop "${CLIENT_DOCKER_NAME}" || true

# ===================================================
# CLIENT COMMAND
ROBOT_CAMERAS="{ front: {type: opencv, index_or_path: ${FRONT_CAM_INDEX}, width: ${CAM_WIDTH}, height: ${CAM_HEIGHT}, fps: ${CAM_FPS}}, wrist: {type: opencv, index_or_path: ${WRIST_CAM_INDEX}, width: ${CAM_WIDTH}, height: ${CAM_HEIGHT}, fps: ${CAM_FPS}} }"

CLIENT_CMD=$(cat <<'EOS'
set -Eeuo pipefail
cd Isaac-GR00T/
python examples/SO-100/eval_lerobot.py \
  --robot.type="${ROBOT_TYPE}" \
  --robot.port="${ROBOT_PORT}" \
  --robot.id="${ROBOT_ID}" \
  --robot.calibration_dir "${CALIB_DIR_CONT}" \
  --robot.cameras="${ROBOT_CAMERAS}" \
  --policy_host=0.0.0.0 \
  --lang_instruction="${LANG_INSTRUCTION}"
EOS
)

CLIENT_ENV_ARGS=(
  -e ROBOT_TYPE="${ROBOT_TYPE}"
  -e ROBOT_PORT="${ROBOT_PORT}"
  -e ROBOT_ID="${ROBOT_ID}"
  -e CALIB_DIR_CONT="${CALIB_DIR_CONT}"
  -e ROBOT_CAMERAS="${ROBOT_CAMERAS}"
  -e LANG_INSTRUCTION="${LANG_INSTRUCTION}"
)

log "Launching CLIENT container: ${CLIENT_DOCKER_NAME}"
CLIENT_RUN_CMD=$(printf '%q ' docker run --name "${CLIENT_DOCKER_NAME}" \
  "${DOCKER_GPU_ARGS[@]}" \
  "${COMMON_DOCKER_ARGS[@]}" \
  -v "${project_root}:${WORKSPACE}:rw" \
  "${CLIENT_ENV_ARGS[@]}" \
  "${CLIENT_IMAGE_NAME}" \
  bash -lc "${CLIENT_CMD}")

echo "------------------------------------------------------------"
echo "[RUN] $CLIENT_RUN_CMD"
echo "------------------------------------------------------------"

# Run client container
eval "$CLIENT_RUN_CMD"

log "Both containers launched."
log "Follow logs with:"
log "  docker logs -f ${SERVER_DOCKER_NAME}"
log "  docker logs -f ${CLIENT_DOCKER_NAME}"
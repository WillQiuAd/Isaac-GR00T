#/bin/bash

# ===================================================
# Global Variables
CLIENT_DOCKER_NAME="isaac-gr00t-thor-client"
SERVER_DOCKER_NAME="isaac-gr00t-thor-server"
CLIENT_IMAGE_NAME="$CLIENT_DOCKER_NAME:dev"
SERVER_IMAGE_NAME="$SERVER_DOCKER_NAME:dev"
WORKSPACE="/workspace"

# ===================================================
# SERVER STEP
docker run --name $SERVER_DOCKER_NAME \
    --privileged --rm -dt --net=host --ipc=host \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video,graphics  \
    --runtime nvidia \
    --device /dev/nvhost-vic \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix  \
    -v /etc/X11:/etc/X11 \
    -w $WORKSPACE \
    -v `pwd`:$WORKSPACE \
    -v /dev:/dev \
    -v /etc/localtime:/etc/localtime:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $SERVER_IMAGE_NAME bash -c "python scripts/inference_service.py --server \
    --model_path so101-checkpoints-grab-pen-wrist-b16-d8-diffusion-tune-best/best-train-loss  \
    --embodiment-tag new_embodiment \
    --data-config so100_dualcam \
    --denoising-steps 4"

# ===================================================
# CLIENT STEP
cd "$(cd "$(dirname "$0")/.." && pwd)"
docker run --name $CLIENT_DOCKER_NAME \
    --privileged --rm -dt --net=host --ipc=host \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,video,graphics  \
    --runtime nvidia \
    --device /dev/nvhost-vic \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix  \
    -v /etc/X11:/etc/X11 \
    -w $WORKSPACE \
    -v `pwd`:$WORKSPACE \
    -v /dev:/dev \
    -v /etc/localtime:/etc/localtime:ro \
    -v /var/run/docker.sock:/var/run/docker.sock \
    $CLIENT_IMAGE_NAME bash -c 'cd Isaac-GR00T/ && python examples/SO-100/eval_lerobot.py \
    --robot.type=so101_follower \
    --robot.port=/dev/ttyACM0 \
    --robot.id=my_awesome_follower_arm \
    --robot.calibration_dir /workspace/.cache/huggingface/lerobot/calibration/robots/so101_follower\
    --robot.cameras="{ front: {type: opencv, index_or_path: 0, width: 1280, height: 720, fps: 30}, wrist: {type: opencv, index_or_path: 2, width: 1280, height: 720, fps: 30}}" \
    --policy_host=0.0.0.0 \
    --lang_instruction="Grab the pen and put it in the box"'
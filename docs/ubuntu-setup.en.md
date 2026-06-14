[日本語](ubuntu-setup.md) | **English**

# Ubuntu Setup Guide

Detailed instructions for running the ROS1 Noetic Docker workspace on Ubuntu (Linux).

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Installing Docker](#2-installing-docker)
3. [Initial Setup](#3-initial-setup)
4. [GUI Tools (RViz / Gazebo)](#4-gui-tools-rviz--gazebo)
5. [CAN Communication](#5-can-communication)
6. [Serial Communication](#6-serial-communication)
7. [Joystick](#7-joystick)
8. [GPU Support (Optional)](#8-gpu-support-optional)

---

## 1. System Requirements

| Item | Requirement |
|---|---|
| OS | Ubuntu 20.04 / 22.04 recommended (other Linux distributions also work) |
| RAM | 8 GB or more (16 GB recommended when using RViz/Gazebo) |
| Storage | 20 GB free space or more |
| Other | Docker 20.10+, docker compose v2+ |

---

## 2. Installing Docker

```bash
# Remove old versions (if any)
sudo apt remove docker docker-engine docker.io containerd runc

# Install required packages
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine and Compose
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add the current user to the docker group (to use without sudo)
sudo usermod -aG docker $USER

# Apply changes (logout/login required)
newgrp docker
```

### Verify Installation

```bash
docker version
docker compose version
docker run hello-world
```

---

## 3. Initial Setup

```bash
# Clone the repository
git clone <repository-url>
cd ros1_docker_ws

# Build the image (takes a few minutes)
make build

# Initialize the catkin workspace
make catkin-init
```

---

## 4. GUI Tools (RViz / Gazebo)

On a Linux host, X11 forwarding allows GUI applications running inside the container to be displayed on the host screen.

### How It Works

When you run `make up` / `make shell` / `make rviz` / `make gazebo`, `xhost +local:docker` is run automatically to allow Docker containers to connect to the host X server. When done, `xhost -local:docker` revokes the permission.

### Launch

```bash
make rviz     # Launch RViz
make gazebo   # Launch Gazebo
```

### Launching Directly from Inside the Container

```bash
make shell

source /opt/ros/noetic/setup.bash
rviz
```

### Troubleshooting: Nothing Displays

```bash
# Check DISPLAY
echo $DISPLAY   # should show something like :0 or :1

# Check xhost settings
xhost

# Grant access manually
xhost +local:docker
```

---

## 5. CAN Communication

Uses SocketCAN-based CAN interfaces (e.g., `can0`).
`network_mode: host` and `privileged: true` allow the container to directly access host CAN interfaces.

> **Not supported on Windows**: SocketCAN is a Linux kernel feature and cannot be used on Windows.

### Host Prerequisites

After connecting a USB-CAN adapter (Peak PCAN, Kvaser, etc.), load the kernel modules on the **host**.

```bash
# Load SocketCAN modules (after first run or reboot)
sudo modprobe can
sudo modprobe can_raw
sudo modprobe can_dev

# For USB-CAN adapters (e.g., Peak PCAN USB)
sudo modprobe peak_usb

# For slcan adapters (USB-to-serial type)
sudo slcand -o -s6 -t hw /dev/ttyUSB0 can0
```

### Bringing CAN Interfaces Up and Down

```bash
# Bring up can0 at 1 Mbps
make can-up IFACE=can0 BITRATE=1000000

# Other bitrate examples
make can-up IFACE=can0 BITRATE=500000   # 500 kbps
make can-up IFACE=can0 BITRATE=250000   # 250 kbps

# Bring down
make can-down IFACE=can0

# Show status (including error counters)
make can-status IFACE=can0
```

### Sending and Receiving Frames

```bash
# Display all received frames (Ctrl+C to stop)
make can-dump IFACE=can0

# Send one frame (ID=0x123, data=0x11 0x22 0x33)
make can-send IFACE=can0 ID=123 DATA="11 22 33"

# Direct operations inside the container
make shell
candump can0                          # receive dump
cansend can0 123#DEADBEEF             # send
cangen can0 -D i -L 8                 # continuous random frames (for testing)
```

### Using CAN from a ROS Node

`ros_canopen` and `socketcan_bridge` are commonly used packages.

```bash
# Using socketcan_bridge (clone into src/ and build)
cd catkin_ws/src
git clone https://github.com/ros-industrial/ros_canopen.git
make rosdep-install
make catkin-build
```

---

## 6. Serial Communication

### Device Passthrough

`docker-compose.yml` shares the entire host `/dev` directory with the container via `/dev:/dev`.
No additional configuration is needed — USB serial devices connected to the host (`/dev/ttyUSB0`, `/dev/ttyACM0`, etc.) are directly accessible from inside the container.

> The container user `ros` belongs to the `dialout` group, so serial devices are accessible without `sudo`.

### Checking Connections

```bash
# List connected serial devices
make serial-list

# Check from inside the container
make shell
ls -l /dev/ttyUSB* /dev/ttyACM*
```

### Fixing Device Names (udev Rules)

If the device name changes every time you plug into a different USB port, you can fix it using a udev rule tied to the serial number.

```bash
# Find the serial number
udevadm info -a -n /dev/ttyUSB0 | grep serial
```

Register it in `/etc/udev/rules.d/99-usb-serial.rules`:

```
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="YOUR_SERIAL", SYMLINK+="ttyMYDEVICE"
```

### Serial Monitor (minicom)

```bash
# Open monitor at 115200 bps
make serial-monitor PORT=/dev/ttyUSB0 BAUD=115200

# minicom controls
#   Ctrl+A → Z  : help
#   Ctrl+A → X  : exit
```

### Using Serial from a ROS Node

```bash
make shell

# Direct access via Python (pyserial)
python3 -c "
import serial
ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)
ser.write(b'hello\n')
print(ser.readline())
"

# Using rosserial (for Arduino, etc.)
rosrun rosserial_python serial_node.py /dev/ttyUSB0 _baud:=115200
```

---

## 7. Joystick

`docker-compose.yml` shares the entire host `/dev` with the container, so a connected joystick is immediately visible inside the container as `/dev/input/js*`.
`entrypoint.sh` automatically assigns the device GID to the `ros` user at container startup — no additional permission setup is needed.

### Checking the Connection

```bash
# Check the device on the host
ls -l /dev/input/js*
# → /dev/input/js0, /dev/input/js1, etc.

# Check from inside the container
make shell
ls -l /dev/input/js*
```

### Launching the joy Node

```bash
# Default (/dev/input/js0)
make joy

# For a different device
make joy JS_DEV=/dev/input/js1
```

Check the topic from another terminal:

```bash
make shell
source /opt/ros/noetic/setup.bash
rostopic echo /joy
```

### When Multiple Joysticks Are Connected

If you are not sure which of `js0` or `js1` is the target device, use `jstest` to identify it:

```bash
make shell
jstest /dev/input/js0
```

---

## 8. GPU Support (Optional)

To use an NVIDIA GPU, uncomment the `deploy` section in `docker-compose.yml`.

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

`nvidia-container-toolkit` must be installed beforehand.

```bash
# Install nvidia-container-toolkit
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker
```

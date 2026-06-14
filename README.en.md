[日本語](README.md) | **English**

# ROS1 Noetic Docker Workspace

A ROS1 Noetic development environment with RViz / Gazebo support.
Source code is managed on the host; **all execution runs inside a Docker container**.
Builds use `catkin build` (catkin-tools), with full support for rosbag recording and playback.

---

## Supported Platforms

| OS | Tool | Setup Guide |
|---|---|---|
| Ubuntu / Linux | `make` | [docs/ubuntu-setup.en.md](docs/ubuntu-setup.en.md) |
| Windows (PowerShell) | `.\run.ps1` | [docs/windows-setup.en.md](docs/windows-setup.en.md) |

---

## Directory Structure

```
ros1_docker_ws/
├── catkin_ws/                     ← Host-managed workspace (tracked by Git)
│   └── src/                       ← Place packages here
├── bags/                          ← rosbag storage (synced with /home/ros/bags in container)
├── docker/
│   ├── Dockerfile                 ← ROS Noetic image definition (shared across OSes)
│   ├── docker-compose.yml         ← Linux (host network, X11 Unix socket)
│   ├── docker-compose.windows.yml ← Windows (bridge network, VcXsrv TCP)
│   └── entrypoint.sh              ← Assigns joystick GIDs and sources setup.bash on startup
├── docs/
│   ├── ubuntu-setup.md / ubuntu-setup.en.md   ← Ubuntu guide (CAN, serial, GUI, etc.)
│   └── windows-setup.md / windows-setup.en.md ← Windows guide (usbipd, VcXsrv, etc.)
├── Makefile                       ← Command set for Ubuntu / Linux
├── run.ps1                        ← Command set for Windows PowerShell
└── .gitignore
```

---

## Quick Start

### Ubuntu / Linux

```bash
# 1. Build the image (first time only — takes a few minutes)
make build

# 2. Initialize the catkin workspace (first time only)
make catkin-init

# 3. Place packages in src/ and build
make rosdep-install   # install dependencies
make catkin-build     # build

# 4. Enter the container to work
make up               # start the container
make shell            # open bash
```

### Windows (PowerShell)

```powershell
# 1. Build the image (first time only — takes a few minutes)
.\run.ps1 build

# 2. Initialize the catkin workspace (first time only)
.\run.ps1 catkin-init

# 3. Place packages in src\ and build
.\run.ps1 rosdep-install   # install dependencies
.\run.ps1 catkin-build     # build

# 4. Enter the container to work
.\run.ps1 up               # start the container
.\run.ps1 shell            # open bash
```

> See the per-OS setup guide for detailed first-time setup instructions.

---

## Using catkin build

This workspace uses `catkin build` (catkin-tools).
Unlike `catkin_make`, it performs efficient parallel and incremental builds.

### Commands

| Operation | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| Initialize workspace (first time only) | `make catkin-init` | `.\run.ps1 catkin-init` |
| Build all packages | `make catkin-build` | `.\run.ps1 catkin-build` |
| Build a specific package | `make catkin-build-pkg PKG=my_pkg` | `.\run.ps1 catkin-build-pkg -PKG my_pkg` |
| Remove build artifacts | `make catkin-clean` | `.\run.ps1 catkin-clean` |

### Inside the container

```bash
# Build everything
catkin build

# Build a specific package
catkin build my_pkg

# Check build status
catkin list

# Show configuration
catkin config
```

> **Note**: Do not use `catkin_make`. It may overwrite `.catkin_tools/` configuration.

---

## Using rosbag

The `bags/` directory is shared between host and container, so bag files recorded inside the container are immediately accessible from the host's `bags/` directory.

### Recording

| Operation | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| Record all topics | `make bag-record` | `.\run.ps1 bag-record` |
| Record specific topics | `make bag-record TOPICS="/cmd_vel /odom"` | `.\run.ps1 bag-record -TOPICS "/cmd_vel /odom"` |

Recordings are saved in `bags/` with a name like `2024-01-01-12-00-00.bag`.
Press **Ctrl+C** to stop recording.

### Playback

| Operation | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| Play at normal speed | `make bag-play BAG=xxx.bag` | `.\run.ps1 bag-play -BAG xxx.bag` |
| Play at custom rate | `make bag-play BAG=xxx.bag RATE=0.5` | `.\run.ps1 bag-play -BAG xxx.bag -RATE 0.5` |
| Show metadata | `make bag-info BAG=xxx.bag` | `.\run.ps1 bag-info -BAG xxx.bag` |
| List files | `make bag-list` | `.\run.ps1 bag-list` |
| Compress with bz2 | `make bag-compress BAG=xxx.bag` | `.\run.ps1 bag-compress -BAG xxx.bag` |

### Inside the container (common)

```bash
# Loop playback
rosbag play --clock --loop /home/ros/bags/2024-01-01-12-00-00.bag

# Play specific topics only
rosbag play /home/ros/bags/2024-01-01-12-00-00.bag --topics /cmd_vel /odom

# Enable use_sim_time
rosparam set use_sim_time true
rosbag play --clock /home/ros/bags/2024-01-01-12-00-00.bag

# GUI operation with rqt_bag (Ubuntu only)
rqt_bag /home/ros/bags/2024-01-01-12-00-00.bag
```

> The `--clock` flag publishes the `/clock` topic.
> When time synchronization is needed in `rospy`/`roscpp`, also set `use_sim_time:=true`.

---

## Command Reference

```bash
make help        # Ubuntu
.\run.ps1 help   # Windows
```

| Command | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| Build image | `build` | `build` |
| Start container | `up` | `up` |
| Stop container | `down` | `down` |
| Enter container | `shell` | `shell` |
| New shell session | `shell-new` | `shell-new` |
| Start roscore | `roscore` | `roscore` |
| Initialize catkin | `catkin-init` | `catkin-init` |
| Build all | `catkin-build` | `catkin-build` |
| Build specific package | `catkin-build-pkg PKG=...` | `catkin-build-pkg -PKG ...` |
| Remove build artifacts | `catkin-clean` | `catkin-clean` |
| Install dependencies | `rosdep-install` | `rosdep-install` |
| Launch RViz | `rviz` | `rviz` |
| Launch Gazebo | `gazebo` | `gazebo` |
| Record rosbag | `bag-record [TOPICS=...]` | `bag-record [-TOPICS ...]` |
| Play rosbag | `bag-play BAG=... [RATE=...]` | `bag-play -BAG ... [-RATE ...]` |
| Bag metadata | `bag-info BAG=...` | `bag-info -BAG ...` |
| Compress bag | `bag-compress BAG=...` | `bag-compress -BAG ...` |
| List bags | `bag-list` | `bag-list` |
| Launch joystick | `joy [JS_DEV=...]` | `joy [-JsDev ...]` |
| Bring up CAN | `can-up [IFACE=...] [BITRATE=...]` | Not supported |
| Bring down CAN | `can-down [IFACE=...]` | Not supported |
| Dump CAN frames | `can-dump [IFACE=...]` | Not supported |
| Send CAN frame | `can-send [IFACE=...] [ID=...] [DATA=...]` | Not supported |
| List serial devices | `serial-list` | `serial-list` |
| Serial monitor | `serial-monitor [PORT=...] [BAUD=...]` | `serial-monitor [-PORT ...] [-BAUD ...]` |

---

## Platform-Specific Details

- **Ubuntu / Linux**: [docs/ubuntu-setup.en.md](docs/ubuntu-setup.en.md)
  GUI (X11), joystick, CAN, serial, GPU support

- **Windows**: [docs/windows-setup.en.md](docs/windows-setup.en.md)
  Docker Desktop, VcXsrv, usbipd-win, joystick, serial, troubleshooting

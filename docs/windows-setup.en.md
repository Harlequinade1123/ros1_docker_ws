[日本語](windows-setup.md) | **English**

# Windows Setup Guide

Step-by-step instructions for running the ROS1 Noetic Docker workspace on Windows.

---

## Table of Contents

1. [System Requirements](#1-system-requirements)
2. [Enable WSL2](#2-enable-wsl2)
3. [Install and Configure Git for Windows](#3-install-and-configure-git-for-windows)
4. [Install and Configure Docker Desktop](#4-install-and-configure-docker-desktop)
5. [Install and Configure VcXsrv (for GUI)](#5-install-and-configure-vcxsrv-for-gui)
6. [Clone the Repository](#6-clone-the-repository)
7. [Initial Setup](#7-initial-setup)
8. [Basic Usage](#8-basic-usage)
9. [USB Device Passthrough (usbipd-win)](#9-usb-device-passthrough-usbipd-win)
10. [Using a Joystick](#10-using-a-joystick)
11. [Serial Communication](#11-serial-communication)
12. [Troubleshooting](#12-troubleshooting)

> **CAN communication**: SocketCAN is a Linux kernel feature. The default WSL2 kernel does not include CAN modules, so **CAN communication is not supported on Windows**. Use the `make` commands in a Linux environment for CAN.

---

## Command Execution Location

This guide uses the following notation to indicate where each command should be run.

| Notation | Location |
|---|---|
| **PowerShell** | Windows PowerShell (normal privileges) |
| **PowerShell (Admin)** | Windows PowerShell (Run as Administrator) |
| **Inside container** | bash after entering via `.\run.ps1 shell` |

The first line of each code block indicates the execution location as a comment.

---

## 1. System Requirements

| Item | Requirement |
|---|---|
| OS | Windows 10 version 2004 or later (Build 19041+) or Windows 11 |
| RAM | 8 GB or more (16 GB recommended) |
| Storage | 20 GB free space or more |
| CPU | Virtualization-capable (Intel VT-x / AMD-V enabled in BIOS) |

> **Check virtualization**: Task Manager → Performance → CPU → confirm "Virtualization: Enabled".

---

## 2. Enable WSL2

WSL2 is required for Docker Desktop to function. Open an elevated PowerShell and run:

```powershell
# Location: PowerShell (Admin)

# Enable WSL and the Virtual Machine Platform
wsl --install

# After reboot, set WSL2 as the default
wsl --set-default-version 2
```

> Reboot if prompted after `wsl --install`.
> Ubuntu will be installed automatically, but you do not need to use it directly — Docker Desktop is sufficient.

---

## 3. Install and Configure Git for Windows

### Installation

Download the latest version from the [official site](https://git-scm.com/download/win) and install.

Recommended options during installation:

| Setting | Recommended Value |
|---|---|
| Default editor | Visual Studio Code (or your preference) |
| PATH environment | **Git from the command line and also from 3rd-party software** |
| Line ending conversion | **Checkout as-is, commit as-is** |
| Terminal | Windows default terminal or Git Bash |

### Initial Configuration

Run the following in **PowerShell** or **Git Bash** after installation.

```powershell
# Location: PowerShell

# User info (required)
git config --global user.name  "Your Name"
git config --global user.email "your@email.com"

# Disable line ending conversion (required to preserve LF in shell scripts)
git config --global core.autocrlf false

# Default branch name (optional)
git config --global init.defaultBranch main
```

> **Important**: Without `core.autocrlf false`, `.sh` files will have CRLF line endings and fail to execute inside Docker containers.
> The repository's `.gitattributes` also enforces LF for `.sh` files, but setting the global option as well is recommended.

---

## 4. Install and Configure Docker Desktop

### Installation

Download "Docker Desktop for Windows" from the [official site](https://www.docker.com/products/docker-desktop/) and install.

### Setup

1. Launch Docker Desktop after installation.
2. If a license agreement screen appears on first launch, click **Accept**.
3. Verify that the WSL 2 based engine is enabled:
   Settings → General → confirm **"Use the WSL 2 based engine"** is checked.

> **Note**: Older versions showed a "Use WSL 2 instead of Hyper-V" option in the initial wizard, but newer versions (Docker Desktop 4.x+) have a simplified wizard where WSL 2 is selected automatically.

> **For heavy GUI tools like Gazebo**: WSL 2 uses up to 50% of host RAM by default, which may slow down the Windows side.
> Consider setting resource limits in `%USERPROFILE%\.wslconfig`.
> Example: `memory=4GB` / `processors=4` / `swap=2GB`

### Verify

```powershell
# Location: PowerShell

docker version
docker compose version
```

If both commands output without errors, you are good to go.

---

## 5. Install and Configure VcXsrv (for GUI)

To use GUI tools such as RViz and Gazebo, you need to run an X server on the Windows side.

> **About WSLg**: Windows 11's WSLg works for apps launched directly from a WSL2 terminal, but **Docker containers started from PowerShell cannot access WSLg**. VcXsrv is required.

### Installation

Download the latest version from [SourceForge](https://sourceforge.net/projects/vcxsrv/) and install.
After installation, **XLaunch** (VcXsrv's configuration and launch tool) appears in the Start menu.

### Launch Configuration

Open **XLaunch** from the Start menu and configure in the following order:

1. **Display settings**: `Multiple windows`, Display number: `0`
2. **Session type**: `Start no client`
3. **Extra settings**:
   - Check `Clipboard`
   - Check `Primary Selection`
   - **Check `Disable access control`** ← important
4. Click **Finish** to launch.

> **Auto-start (optional)**: After configuring, click "Save configuration" to save `config.xlaunch`,
> then place it in the startup folder (`shell:startup`) to launch automatically at boot.

### Windows Firewall

If a firewall permission dialog appears on first launch, allow VcXsrv on **both "Private" and "Public" networks**.

---

## 6. Clone the Repository

Open PowerShell and clone the repository to a directory of your choice.

```powershell
# Location: PowerShell

# Example: placing in C:\Users\username\Projects
cd C:\Users\$env:USERNAME\Projects

git clone <repository-url>
cd ros1_docker_ws
```

---

## 7. Initial Setup

### Set PowerShell Execution Policy

Allow script execution (no admin privileges required).

```powershell
# Location: PowerShell

Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Build the Docker Image

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 build
```

This takes a few minutes the first time.

### Initialize the catkin Workspace

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 catkin-init
```

---

## 8. Basic Usage

All commands are run from the repository root as `.\run.ps1 <command>`.

### Starting and Stopping the Container

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 up        # start the container in the background
.\run.ps1 shell     # enter bash in the running container
.\run.ps1 down      # stop the container
```

### catkin Build

```powershell
# Location: PowerShell (run from the repository root directory)

# After placing packages in src/
.\run.ps1 rosdep-install   # install dependencies
.\run.ps1 catkin-build     # build

# Build a specific package
.\run.ps1 catkin-build-pkg -PKG my_package
```

### GUI Tools (RViz / Gazebo)

Make sure XLaunch is running before executing these.

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 rviz    # Launch RViz
.\run.ps1 gazebo  # Launch Gazebo
```

### Joystick

Complete the usbipd-win attach in [Section 10](#10-using-a-joystick) before using a joystick.

```powershell
# Location: PowerShell (run from the repository root directory)

# Default (/dev/input/js0)
.\run.ps1 joy

# Specify a device
.\run.ps1 joy -JsDev /dev/input/js1
```

### rosbag

```powershell
# Location: PowerShell (run from the repository root directory)

# Record all topics
.\run.ps1 bag-record

# Record specific topics
.\run.ps1 bag-record -TOPICS "/cmd_vel /odom /scan"

# Play at normal speed
.\run.ps1 bag-play -BAG 2024-01-01-12-00-00.bag

# Play at 0.5x speed
.\run.ps1 bag-play -BAG 2024-01-01-12-00-00.bag -RATE 0.5

# Show metadata
.\run.ps1 bag-info -BAG 2024-01-01-12-00-00.bag

# List files
.\run.ps1 bag-list
```

### Command Reference

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 help
```

---

## 9. USB Device Passthrough (usbipd-win)

On Windows, Docker containers cannot directly access USB devices. Use **usbipd-win** to pass them through to WSL2 and then into the container. USB serial adapters (CH340, FTDI, etc.) use this procedure.

### 9-1. Install usbipd-win

Run the following in an **elevated PowerShell** (using winget).

```powershell
# Location: PowerShell (Admin)

winget install usbipd
```

Alternatively, download the latest installer from [GitHub](https://github.com/dorssel/usbipd-win) and install it.

Restart PowerShell after installation.

### 9-2. Check Docker Desktop WSL Integration

In Docker Desktop, go to Settings → Resources → **WSL Integration** and confirm that your WSL2 distribution (usually Ubuntu) is enabled.

### 9-3. Attach a USB Device (Required Each Session)

After connecting the USB device to your PC, run the following in an **elevated PowerShell**.

**Step 1: List connected USB devices**

```powershell
# Location: PowerShell (Admin)

usbipd list
```

Example output:
```
BUSID  VID:PID    DEVICE                              STATE
2-1    0403:6001  USB Serial Converter (CH340)        Not shared
2-3    046d:c52b  USB Receiver                        Not shared
```

**Step 2: Bind the device (first time only)**

The `BUSID` may change if you plug the device into a different USB port.
Run this step the first time or whenever the BUSID changes.

```powershell
# Location: PowerShell (Admin)

usbipd bind --busid 2-1
```

Running `usbipd list` again will show `STATE` as `Shared`.

**Step 3: Attach to WSL2**

Run this **before** starting the Docker container.

```powershell
# Location: PowerShell (Admin)

usbipd attach --wsl --busid 2-1
```

Success is indicated when `STATE` shows `Attached`.

### 9-4. Enable Device Configuration in docker-compose.windows.yml

Open `docker/docker-compose.windows.yml` and uncomment the `devices` section.

```yaml
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0    # CH340, FTDI, etc.
      # - /dev/ttyACM0:/dev/ttyACM0  # Arduino CDC ACM devices
```

Verify the device node name by running `ls /dev/ttyUSB* /dev/ttyACM*` inside the container.

### 9-5. Restart the Container to Apply Changes

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 down
.\run.ps1 up
```

### 9-6. Detach the Device

Run this before physically unplugging the device or when ending the session.

```powershell
# Location: PowerShell (Admin)

usbipd detach --busid 2-1
```

> **Note**: After restarting the container or rebooting the PC, you must repeat Step 3 (`usbipd attach`). Step 2 (bind) does not need to be repeated.

---

## 10. Using a Joystick

Gamepads and joysticks can also be passed through to the container via usbipd-win.

### 10-1. Attach the Joystick via usbipd-win

Follow the same procedure as [Section 9-1 through 9-3](#9-usb-device-passthrough-usbipd-win) using the joystick's BUSID.

```powershell
# Location: PowerShell (Admin)

# List devices to find the joystick BUSID
usbipd list

# Bind (first time only)
usbipd bind --busid <BUSID>

# Attach to WSL2
usbipd attach --wsl --busid <BUSID>
```

After attaching, `/dev/input/js0` (or `js1`) will appear in WSL2.

### 10-2. Verify docker-compose.windows.yml

Confirm that the following volume mount is present in `docker/docker-compose.windows.yml` (enabled by default).

```yaml
volumes:
  - /dev/input:/dev/input    # joystick (after usbipd-win attach)
```

> If `/dev/input` does not exist in WSL2 (no joystick connected), comment out this line before starting the container.

### 10-3. Launch the joy Node

```powershell
# Location: PowerShell (run from the repository root directory)

# Default (/dev/input/js0)
.\run.ps1 joy

# Specify a device
.\run.ps1 joy -JsDev /dev/input/js1
```

When the command runs, `Test-UsbIpdJoystick` performs an automatic check and displays a warning if the device is not found.

### 10-4. Verify the Topic

Open another PowerShell window, enter the container, and check the `/joy` topic.

```powershell
.\run.ps1 shell
```

```bash
# Inside container
source /opt/ros/noetic/setup.bash
rostopic echo /joy
```

---

## 11. Serial Communication

This section assumes that the USB passthrough in [Section 9](#9-usb-device-passthrough-usbipd-win) (`usbipd attach`) is already complete.

### Check the Device

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 serial-list
```

Or check directly from inside the container:

```powershell
# Location: PowerShell → enter the container
.\run.ps1 shell
```

```bash
# Inside container
ls -l /dev/ttyUSB* /dev/ttyACM*
```

### Serial Monitor (minicom)

```powershell
# Location: PowerShell (run from the repository root directory)

.\run.ps1 serial-monitor -PORT /dev/ttyUSB0 -BAUD 115200
```

minicom controls:
- `Ctrl+A` → `Z` : help
- `Ctrl+A` → `X` : exit

### Python Access

```powershell
# Location: PowerShell → enter the container
.\run.ps1 shell
```

```bash
# Inside container
python3 -c "
import serial
ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)
ser.write(b'hello\n')
print(ser.readline())
"
```

### Fixing Device Node Names

If the device name changes (e.g., `/dev/ttyUSB0` → `/dev/ttyUSB1`) when plugging into a different port, you can fix it using a udev rule on the WSL2 host.

```bash
# Location: WSL2 or Linux host

udevadm info -a -n /dev/ttyUSB0 | grep -i serial
```

Register the obtained serial number in `/etc/udev/rules.d/99-usb-serial.rules`:

```
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="YOUR_SERIAL", SYMLINK+="ttyMYDEVICE"
```

---

## 12. Troubleshooting

### Docker Won't Start

- Check that Docker Desktop is running (Docker icon in the taskbar).
- Verify WSL2 is configured correctly:
  ```powershell
  # Location: PowerShell
  wsl --status
  ```

### GUI (RViz/Gazebo) Does Not Display

1. Check that XLaunch is running (X icon in the taskbar).
2. Confirm "Disable access control" was checked when launching XLaunch.
3. Confirm VcXsrv is allowed through Windows Firewall:
   Settings → Windows Security → Firewall → Allow an app.
4. Check DISPLAY inside the container:
   ```powershell
   # Location: PowerShell → enter the container
   .\run.ps1 shell
   ```

   ```bash
   # Inside container
   echo $DISPLAY          # → host.docker.internal:0.0
   xeyes                  # test GUI app
   ```

### `.\run.ps1` Gives a Script Execution Error

Check and set the PowerShell execution policy.

```powershell
# Location: PowerShell

Get-ExecutionPolicy -List
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### catkin build Fails with Permission Error

If Docker cannot access `catkin_ws/` on Windows, check that the drive is shared in Docker Desktop: Settings → Resources → File sharing.

### USB Device Not Recognized (usbipd-win)

```powershell
# Location: PowerShell (Admin)

# Check attach status
usbipd list

# Re-attach
usbipd detach --busid <BUSID>
usbipd attach --wsl --busid <BUSID>
```

Sometimes re-attaching after restarting the Docker container resolves the issue.

If you attached via usbipd after the container was already running, uncomment `devices` in `docker/docker-compose.windows.yml` and restart the container.

### Port 11311 Already in Use

```powershell
# Location: PowerShell

# Find the process using the port
netstat -ano | findstr :11311

# Stop the container if needed
.\run.ps1 down
```

### ROS_MASTER_URI When Using the roscore Profile

When running roscore in a separate container (`.\run.ps1 roscore`), you need to update `ROS_MASTER_URI` for the `ros` service in `docker/docker-compose.windows.yml`.

```yaml
environment:
  - ROS_MASTER_URI=http://roscore:11311   # use the roscore container name
  - ROS_HOSTNAME=ros1_ws
```

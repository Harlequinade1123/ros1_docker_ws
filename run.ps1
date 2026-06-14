<#
.SYNOPSIS
    ROS1 Noetic Docker Workspace - Windows command runner

.DESCRIPTION
    Windows PowerShell equivalent of the Linux Makefile.
    Uses docker/docker-compose.windows.yml.

.EXAMPLE
    .\run.ps1 build
    .\run.ps1 up
    .\run.ps1 shell
    .\run.ps1 catkin-build
    .\run.ps1 bag-play -BAG 2024-01-01-12-00-00.bag -RATE 0.5
    .\run.ps1 help
#>

param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [string]$PKG    = "",
    [string]$BAG    = "",
    [string]$TOPICS = "-a",
    [double]$RATE   = 1.0,
    [string]$IFACE  = "can0",
    [int]$BITRATE   = 1000000,
    [string]$ID     = "123",
    [string]$DATA   = "11.22.33.44",
    [string]$PORT   = "/dev/ttyUSB0",
    [int]$BAUD      = 115200,
    [string]$JsDev  = "/dev/input/js0"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$COMPOSE_FILE = "docker/docker-compose.windows.yml"
$BAG_DIR      = "/home/ros/bags"

# ── Helper functions ─────────────────────────────────────────────

function Invoke-Compose {
    param([string[]]$ComposeArgs)
    & docker compose -f $COMPOSE_FILE @ComposeArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-InRos {
    param([string]$BashCmd)
    docker compose -f $COMPOSE_FILE exec -u ros ros bash -c $BashCmd
}

function Test-VcXsrv {
    $proc = Get-Process -Name "vcxsrv" -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Warning "VcXsrv is not running. Start VcXsrv before using GUI tools (RViz/Gazebo)."
        Write-Warning "Setup guide: docs\windows-setup.md"
    }
}

function Test-UsbIpdJoystick {
    param([string]$Dev = "/dev/input/js0")
    # Check whether the joystick device is visible in WSL2
    $result = wsl -- test -e $Dev 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Joystick device ($Dev) not found in WSL2."
        Write-Warning "Steps: 1) Run 'usbipd list' to find the device bus ID"
        Write-Warning "       2) Run 'usbipd attach --wsl --busid <ID>' to attach it"
        Write-Warning "       3) Re-run this command"
    }
}

# ── Commands ─────────────────────────────────────────────────────

switch ($Command.ToLower()) {

    # ── Docker ──────────────────────────────────────────────────
    "build" {
        Invoke-Compose @("build")
    }

    "up" {
        New-Item -ItemType Directory -Force -Path "catkin_ws\src", "bags" | Out-Null
        Invoke-Compose @("up", "-d")
    }

    "down" {
        Invoke-Compose @("down")
    }

    "shell" {
        Invoke-Compose @("exec", "-u", "ros", "ros", "bash")
    }

    "shell-new" {
        docker exec -it -u ros ros1_ws bash
    }

    # ── catkin ──────────────────────────────────────────────────
    "catkin-init" {
        Invoke-InRos ("source /opt/ros/noetic/setup.bash && " +
                      "catkin init && " +
                      "catkin config --extend /opt/ros/noetic --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo")
    }

    "catkin-build" {
        Invoke-InRos "source /opt/ros/noetic/setup.bash && catkin build"
    }

    "catkin-build-pkg" {
        if (-not $PKG) {
            Write-Error "Usage: .\run.ps1 catkin-build-pkg -PKG <package_name>"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && catkin build $PKG"
    }

    "catkin-clean" {
        Invoke-InRos "catkin clean -y"
    }

    # ── rosdep ──────────────────────────────────────────────────
    "rosdep-install" {
        Invoke-InRos "cd /home/ros/catkin_ws && rosdep install --from-paths src --ignore-src -r -y"
    }

    # ── Joystick ────────────────────────────────────────────────
    "joy" {
        Test-UsbIpdJoystick -Dev $JsDev
        Invoke-InRos ("source /opt/ros/noetic/setup.bash && " +
                      "rosrun joy joy_node _dev:=$JsDev")
    }

    # ── GUI ─────────────────────────────────────────────────────
    "roscore" {
        Invoke-InRos "source /opt/ros/noetic/setup.bash && roscore"
    }

    "rviz" {
        Test-VcXsrv
        Invoke-InRos ("source /opt/ros/noetic/setup.bash && " +
                      "source /home/ros/catkin_ws/devel/setup.bash 2>/dev/null || true && " +
                      "rviz")
    }

    "gazebo" {
        Test-VcXsrv
        Invoke-InRos "source /opt/ros/noetic/setup.bash && roslaunch gazebo_ros empty_world.launch"
    }

    # ── rosbag ──────────────────────────────────────────────────
    "bag-record" {
        Invoke-InRos "source /opt/ros/noetic/setup.bash && mkdir -p $BAG_DIR && rosbag record -o $BAG_DIR/ $TOPICS"
    }

    "bag-play" {
        if (-not $BAG) {
            Write-Error "Usage: .\run.ps1 bag-play -BAG <filename> [-RATE <speed>]"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && rosbag play --clock -r $RATE $BAG_DIR/$BAG"
    }

    "bag-info" {
        if (-not $BAG) {
            Write-Error "Usage: .\run.ps1 bag-info -BAG <filename>"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && rosbag info $BAG_DIR/$BAG"
    }

    "bag-compress" {
        if (-not $BAG) {
            Write-Error "Usage: .\run.ps1 bag-compress -BAG <filename>"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && rosbag compress --bz2 $BAG_DIR/$BAG"
    }

    "bag-list" {
        Invoke-InRos "ls -lh $BAG_DIR/*.bag 2>/dev/null || echo '(no bag files found)'"
    }

    # ── CAN (not supported on Windows) ──────────────────────────
    # SocketCAN is a Linux kernel feature. The default WSL2 kernel does not
    # include CAN modules. Use 'make can-*' in a Linux environment instead.

    "can-up" {
        Write-Warning "CAN is not supported on Windows. Use 'make can-up' in a Linux environment."
    }

    "can-down" {
        Write-Warning "CAN is not supported on Windows. Use 'make can-down' in a Linux environment."
    }

    "can-status" {
        Write-Warning "CAN is not supported on Windows. Use 'make can-status' in a Linux environment."
    }

    "can-dump" {
        Write-Warning "CAN is not supported on Windows. Use 'make can-dump' in a Linux environment."
    }

    "can-send" {
        Write-Warning "CAN is not supported on Windows. Use 'make can-send' in a Linux environment."
    }

    # ── Serial ──────────────────────────────────────────────────
    # Note: USB serial devices must be passed through via usbipd-win
    # See: docs\windows-setup.md

    "serial-list" {
        Invoke-InRos "ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null || echo '(no serial devices found)'"
    }

    "serial-monitor" {
        Invoke-InRos "minicom -D $PORT -b $BAUD"
    }

    # ── Help ────────────────────────────────────────────────────
    "help" {
        Write-Host @"
ROS1 Noetic Docker - Windows command runner (run.ps1)

Usage: .\run.ps1 <command> [options]

[Docker]
  build                              Build the Docker image
  up                                 Start the container in the background
  down                               Stop and remove the container
  shell                              Open a bash shell in the running container
  shell-new                          Open an additional bash shell

[catkin]
  catkin-init                        Initialize the catkin workspace (first time only)
  catkin-build                       Build all packages
  catkin-build-pkg -PKG <name>       Build a specific package
  catkin-clean                       Remove build artifacts

[ROS]
  rosdep-install                     Install dependencies from src/
  roscore                            Start roscore in the background
  joy [-JsDev /dev/input/js0]        Launch joy_node (requires usbipd-win)
  rviz                               Launch RViz (requires VcXsrv)
  gazebo                             Launch Gazebo (requires VcXsrv)

[rosbag]
  bag-record [-TOPICS "/t1 /t2"]           Record topics
  bag-play   -BAG <filename> [-RATE 0.5]  Play a bag file
  bag-info   -BAG <filename>              Show bag metadata
  bag-compress -BAG <filename>            Compress bag with bz2
  bag-list                                List bag files

[CAN]  Not supported on Windows — use 'make can-*' in a Linux environment

[Serial]  USB serial devices require usbipd-win passthrough (see docs\windows-setup.md)
  serial-list
  serial-monitor [-PORT /dev/ttyUSB0] [-BAUD 115200]

Setup guide: docs\windows-setup.md
"@
    }

    default {
        Write-Error "Unknown command: '$Command'`nRun '.\run.ps1 help' to see available commands."
        exit 1
    }
}

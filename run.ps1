#Requires -Version 5.1
<#
.SYNOPSIS
    ROS1 Noetic Docker ワークスペース - Windows 用コマンドランナー

.DESCRIPTION
    Linux の Makefile に相当する Windows (PowerShell) 版スクリプト。
    docker/docker-compose.windows.yml を使用します。

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
    [string]$DATA   = "00 00 00 00",
    [string]$PORT   = "/dev/ttyUSB0",
    [int]$BAUD      = 115200
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$COMPOSE_FILE = "docker/docker-compose.windows.yml"
$BAG_DIR      = "/home/ros/bags"

# ── ヘルパー関数 ─────────────────────────────────────────────────────

function Invoke-Compose {
    param([string[]]$ComposeArgs)
    & docker compose -f $COMPOSE_FILE @ComposeArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Invoke-InRos {
    param([string]$BashCmd)
    & docker compose -f $COMPOSE_FILE run --rm ros bash -c $BashCmd
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

function Test-VcXsrv {
    $proc = Get-Process -Name "vcxsrv" -ErrorAction SilentlyContinue
    if (-not $proc) {
        Write-Warning "VcXsrv が起動していません。GUI ツール (RViz/Gazebo) を使用するには VcXsrv を先に起動してください。"
        Write-Warning "セットアップ手順: docs\windows-setup.md を参照"
    }
}

# ── コマンド ─────────────────────────────────────────────────────────

switch ($Command.ToLower()) {

    # ── Docker ──────────────────────────────────────────────────────
    "build" {
        Invoke-Compose @("build")
    }

    "up" {
        Invoke-Compose @("up", "-d")
    }

    "down" {
        Invoke-Compose @("down")
    }

    "shell" {
        & docker exec -it ros1_ws bash
    }

    "shell-new" {
        Invoke-Compose @("run", "--rm", "ros", "bash")
    }

    # ── catkin ──────────────────────────────────────────────────────
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
            Write-Error "使い方: .\run.ps1 catkin-build-pkg -PKG <パッケージ名>"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && catkin build $PKG"
    }

    "catkin-clean" {
        Invoke-InRos "catkin clean -y"
    }

    # ── rosdep ──────────────────────────────────────────────────────
    "rosdep-install" {
        Invoke-InRos "cd /home/ros/catkin_ws && rosdep install --from-paths src --ignore-src -r -y"
    }

    # ── GUI ─────────────────────────────────────────────────────────
    "roscore" {
        Invoke-Compose @("--profile", "with-roscore", "up", "roscore")
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

    # ── rosbag ──────────────────────────────────────────────────────
    "bag-record" {
        Invoke-InRos "source /opt/ros/noetic/setup.bash && mkdir -p $BAG_DIR && rosbag record -o $BAG_DIR/ $TOPICS"
    }

    "bag-play" {
        if (-not $BAG) {
            Write-Error "使い方: .\run.ps1 bag-play -BAG <ファイル名> [-RATE <倍率>]"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && rosbag play --clock -r $RATE $BAG_DIR/$BAG"
    }

    "bag-info" {
        if (-not $BAG) {
            Write-Error "使い方: .\run.ps1 bag-info -BAG <ファイル名>"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && rosbag info $BAG_DIR/$BAG"
    }

    "bag-compress" {
        if (-not $BAG) {
            Write-Error "使い方: .\run.ps1 bag-compress -BAG <ファイル名>"
            exit 1
        }
        Invoke-InRos "source /opt/ros/noetic/setup.bash && rosbag compress --bz2 $BAG_DIR/$BAG"
    }

    "bag-list" {
        Invoke-InRos "ls -lh $BAG_DIR/*.bag 2>/dev/null || echo '(bag ファイルがありません)'"
    }

    # ── CAN 通信 (Windows 非対応) ───────────────────────────────────
    # SocketCAN は Linux カーネルの機能です。WSL2 のデフォルトカーネルには
    # CAN モジュールが含まれておらず、Windows では使用できません。
    # CAN 通信が必要な場合は Linux 環境（Makefile）を使用してください。

    "can-up" {
        Write-Error "CAN 通信は Windows では非対応です。Linux 環境で make can-up を使用してください。"
        exit 1
    }

    "can-down" {
        Write-Error "CAN 通信は Windows では非対応です。Linux 環境で make can-down を使用してください。"
        exit 1
    }

    "can-status" {
        Write-Error "CAN 通信は Windows では非対応です。Linux 環境で make can-status を使用してください。"
        exit 1
    }

    "can-dump" {
        Write-Error "CAN 通信は Windows では非対応です。Linux 環境で make can-dump を使用してください。"
        exit 1
    }

    "can-send" {
        Write-Error "CAN 通信は Windows では非対応です。Linux 環境で make can-send を使用してください。"
        exit 1
    }

    # ── シリアル通信 ─────────────────────────────────────────────────
    # 注意: usbipd-win で USB シリアルデバイスをコンテナに渡す必要があります
    # 参照: docs\windows-setup.md

    "serial-list" {
        Invoke-InRos "ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null || echo '(デバイスが見つかりません)'"
    }

    "serial-monitor" {
        Invoke-InRos "minicom -D $PORT -b $BAUD"
    }

    # ── ヘルプ ──────────────────────────────────────────────────────
    "help" {
        Write-Host @"
ROS1 Noetic Docker - Windows コマンドランナー (run.ps1)

使い方: .\run.ps1 <コマンド> [オプション]

[Docker]
  build                              Dockerイメージをビルド
  up                                 コンテナをバックグラウンドで起動
  down                               コンテナを停止・削除
  shell                              実行中コンテナにbashで入る
  shell-new                          新しいシェルセッションを起動

[catkin]
  catkin-init                        catkinワークスペースを初期化 (初回のみ)
  catkin-build                       ワークスペース全体をビルド
  catkin-build-pkg -PKG <名前>       特定パッケージのみビルド
  catkin-clean                       ビルド成果物を削除

[ROS]
  rosdep-install                     src/ の依存パッケージをインストール
  roscore                            roscore専用コンテナを起動
  rviz                               RVizを起動 (VcXsrv必要)
  gazebo                             Gazeboを起動 (VcXsrv必要)

[rosbag]
  bag-record [-TOPICS "/t1 /t2"]           録画
  bag-play   -BAG <ファイル名> [-RATE 0.5] 再生
  bag-info   -BAG <ファイル名>             メタ情報を表示
  bag-compress -BAG <ファイル名>           bz2圧縮
  bag-list                                 bags/ 内のファイル一覧

[CAN通信]  ※ Windows では非対応 — Linux 環境（make コマンド）を使用してください

[シリアル通信]  ※ usbipd-win でのデバイスパススルーが必要（docs\windows-setup.md 参照）
  serial-list
  serial-monitor [-PORT /dev/ttyUSB0] [-BAUD 115200]

詳細な環境構築手順: docs\windows-setup.md
"@
    }

    default {
        Write-Error "不明なコマンド: '$Command'`n.\run.ps1 help でコマンド一覧を確認してください"
        exit 1
    }
}

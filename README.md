# ROS1 Noetic Docker ワークスペース

RViz / Gazebo 対応の ROS1 Noetic 開発環境です。  
ソースコードはホストで管理し、**実行はすべて Docker コンテナ内**で行います。  
ビルドには `catkin build`（catkin-tools）を使用し、rosbag の録画・再生にも対応しています。

---

## ディレクトリ構成

```
ros1_ws/
├── catkin_ws/              ← ホスト管理ワークスペース (Git 管理対象)
│   └── src/                ← ここにパッケージを置く
├── bags/                   ← rosbag の保存先（コンテナ /home/ros/bags と同期）
│   └── .gitkeep
├── docker/
│   ├── Dockerfile          ← ROS Noetic + RViz/Gazebo/rosbag イメージ定義
│   └── entrypoint.sh       ← 起動時に setup.bash を自動 source
├── .devcontainer/          ← VS Code Dev Container 設定
├── docker-compose.yml      ← X11 転送・bags マウント設定済み
├── Makefile                ← よく使うコマンド集
└── .gitignore
```

---

## クイックスタート

```bash
# 1. イメージをビルド（初回のみ、数分かかります）
make build

# 2. ワークスペースを初期化（初回のみ）
make catkin-init

# 3. パッケージを src/ に配置してビルド
make rosdep-install   # 依存パッケージをインストール
make catkin-build     # ビルド

# 4. コンテナに入って作業
make up               # コンテナ起動
make shell            # bash に入る
```

---

## catkin build の使い方

このワークスペースは `catkin build`（catkin-tools）を使用します。  
`catkin_make` とは異なり、並列・差分ビルドが効率的に動作します。

### 基本操作

| コマンド | 内容 |
|---|---|
| `make catkin-init` | ワークスペースを初期化（初回のみ） |
| `make catkin-build` | 全パッケージをビルド |
| `make catkin-build-pkg PKG=my_pkg` | 特定パッケージのみビルド |
| `make catkin-clean` | ビルド成果物を削除 |

### コンテナ内での操作

```bash
make shell   # コンテナに入る

# 全体ビルド
catkin build

# 特定パッケージのみ
catkin build my_pkg

# ビルド状況を確認
catkin list

# 設定を確認
catkin config
```

> **注意**: `catkin_make` は使用しないでください。`.catkin_tools/` の設定が上書きされる場合があります。

---

## rosbag の使い方

`bags/` ディレクトリがホストとコンテナ間で共有されているため、  
コンテナ内で録画した bag ファイルはホストの `bags/` からそのまま参照できます。

### 録画（record）

```bash
# 全トピックを録画
make bag-record

# 指定したトピックのみ録画
make bag-record TOPICS="/cmd_vel /odom /scan"

# コンテナ内で直接実行する場合
make shell
rosbag record -o /home/ros/bags/ /cmd_vel /odom /scan
```

録画ファイルは `bags/` に `2024-01-01-12-00-00.bag` のような名前で保存されます。  
録画を止めるには **Ctrl+C** を押します。

### 再生（play）

```bash
# 通常速度で再生
make bag-play BAG=2024-01-01-12-00-00.bag

# 0.5倍速で再生
make bag-play BAG=2024-01-01-12-00-00.bag RATE=0.5

# コンテナ内で直接実行する場合（--clock で /clock トピックを発行）
make shell
rosbag play --clock -r 1.0 /home/ros/bags/2024-01-01-12-00-00.bag

# ループ再生
rosbag play --clock --loop /home/ros/bags/2024-01-01-12-00-00.bag

# 特定トピックのみ再生
rosbag play /home/ros/bags/2024-01-01-12-00-00.bag --topics /cmd_vel /odom
```

> **注意**: `--clock` オプションを付けると `/clock` トピックが発行されます。  
> `rospy`/`roscpp` で時刻同期が必要な場合は `use_sim_time:=true` も設定してください。

```bash
# use_sim_time を有効にする場合
rosparam set use_sim_time true
rosbag play --clock /home/ros/bags/2024-01-01-12-00-00.bag
```

### 情報確認・管理

```bash
# bag ファイルのメタ情報を確認（トピック一覧・時間・サイズなど）
make bag-info BAG=2024-01-01-12-00-00.bag

# bags/ 内のファイル一覧
make bag-list

# bz2 圧縮（ファイルサイズを削減）
make bag-compress BAG=2024-01-01-12-00-00.bag
```

### rqt_bag で GUI 操作

```bash
make shell
rqt_bag /home/ros/bags/2024-01-01-12-00-00.bag
```

rqt_bag ではトピックの波形確認や、範囲を指定した再生ができます。

---

## GUI ツール（RViz / Gazebo）

Linux ホストでは X11 転送により RViz / Gazebo が使えます。

```bash
make rviz     # RViz を起動
make gazebo   # Gazebo を起動
```

> `make up` / `make down` / `make shell` / `make rviz` / `make gazebo` 実行時に `xhost +local:docker` が自動実行されます。

---

## コマンド一覧

```bash
make help
```

| コマンド | 説明 |
|---|---|
| `build` | Docker イメージをビルド |
| `up` | コンテナをバックグラウンドで起動 |
| `down` | コンテナを停止・削除 |
| `shell` | 実行中コンテナに入る |
| `shell-new` | 新しいコンテナセッションを起動 |
| `roscore` | roscore 専用コンテナを起動（`--profile with-roscore`） |
| `catkin-init` | catkin ワークスペース初期化 |
| `catkin-build` | ワークスペース全体をビルド |
| `catkin-build-pkg PKG=...` | 特定パッケージのみビルド |
| `catkin-clean` | ビルド成果物を削除 |
| `rosdep-install` | src/ の依存を自動インストール |
| `rviz` | RViz を起動 |
| `gazebo` | Gazebo を起動 |
| `bag-record [TOPICS=...]` | rosbag を録画 |
| `bag-play BAG=... [RATE=...]` | rosbag を再生 |
| `bag-info BAG=...` | bag のメタ情報を表示 |
| `bag-compress BAG=...` | bag を bz2 圧縮 |
| `bag-list` | bags/ 内のファイル一覧 |

---

## VS Code Dev Container

`.devcontainer/devcontainer.json` が含まれているため、Dev Container でそのまま開発できます。

1. VS Code で `ros1_ws/` を開く
2. 左下 `><` → `Reopen in Container`

---

## CAN 通信

SocketCAN ベースの CAN インターフェース（`can0` など）を使用します。  
`network_mode: host` と `cap_add: NET_ADMIN` により、ホストの CAN インターフェースをそのままコンテナ内から操作できます。

### ホスト側の事前準備

USB-CAN アダプタ（Peak PCAN、Kvaser 等）を接続後、**ホスト側**でカーネルモジュールをロードします。

```bash
# SocketCAN モジュールの読み込み（初回 or 再起動後）
sudo modprobe can
sudo modprobe can_raw
sudo modprobe can_dev

# USB-CAN アダプタの場合（例: Peak PCAN USB）
sudo modprobe peak_usb

# slcan 系アダプタ（USB-シリアル変換タイプ）の場合
sudo slcand -o -s6 -t hw /dev/ttyUSB0 can0
```

### CAN インターフェースの起動・停止

```bash
# can0 を 1Mbps で起動
make can-up IFACE=can0 BITRATE=1000000

# 他のビットレート例
make can-up IFACE=can0 BITRATE=500000   # 500kbps
make can-up IFACE=can0 BITRATE=250000   # 250kbps

# 停止
make can-down IFACE=can0

# 状態確認（エラーカウント等も表示）
make can-status IFACE=can0
```

### フレームの送受信確認

```bash
# 受信フレームをすべて表示（Ctrl+C で停止）
make can-dump IFACE=can0

# フレームを1回送信（ID=0x123, データ=0x11 0x22 0x33）
make can-send IFACE=can0 ID=123 DATA="11 22 33"

# コンテナ内で直接操作する場合
make shell
candump can0                          # 受信ダンプ
cansend can0 123#DEADBEEF             # 送信
cangen can0 -D i -L 8                 # ランダムフレームを連続送信（テスト用）
```

### ROS ノードから CAN を使う場合

`ros_canopen` や `socketcan_bridge` パッケージが代表的です。

```bash
# socketcan_bridge を使う場合（src/ にクローンしてビルド）
cd catkin_ws/src
git clone https://github.com/ros-industrial/ros_canopen.git
make rosdep-install
make catkin-build
```

---

## シリアル通信

### デバイスのパススルー設定

`docker-compose.yml` では `/dev:/dev` でホストの全デバイスをコンテナに共有しています。  
追加の設定は不要で、ホストに接続した USB-シリアルデバイス（`/dev/ttyUSB0`、`/dev/ttyACM0` 等）はそのままコンテナ内から使用できます。

> **補足**: コンテナ内ユーザー `ros` は `dialout` グループに所属しているため、`sudo` なしでシリアルデバイスにアクセスできます。

### 接続確認

```bash
# 接続中のシリアルデバイス一覧
make serial-list

# デバイス名が変わる場合はシリアル番号で固定する（ホスト側）
udevadm info -a -n /dev/ttyUSB0 | grep serial
# → /etc/udev/rules.d/99-usb-serial.rules に登録すると /dev/my_device で固定できる
```

### シリアルモニタ（minicom）

```bash
# 115200bps でモニタを開く
make serial-monitor PORT=/dev/ttyUSB0 BAUD=115200

# minicom の操作
#   Ctrl+A → Z  : ヘルプ
#   Ctrl+A → X  : 終了
```

### ROS ノードからシリアルを使う場合

```bash
make shell

# Python (pyserial) で直接アクセス
python3 -c "
import serial
ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=1)
ser.write(b'hello\n')
print(ser.readline())
"

# rosserial（Arduino 等との連携）を使う場合
rosrun rosserial_python serial_node.py /dev/ttyUSB0 _baud:=115200
```

---

## GPU サポート（任意）

NVIDIA GPU を使う場合は `docker-compose.yml` の `deploy` セクションをアンコメントしてください。

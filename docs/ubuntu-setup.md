# Ubuntu セットアップガイド

ROS1 Noetic Docker ワークスペースを Ubuntu (Linux) で動かすための詳細手順書です．

---

## 目次

1. [システム要件](#1-システム要件)
2. [Docker のインストール](#2-docker-のインストール)
3. [初回セットアップ](#3-初回セットアップ)
4. [GUI ツール（RViz / Gazebo）](#4-gui-ツールrviz--gazebo)
5. [CAN 通信](#5-can-通信)
6. [シリアル通信](#6-シリアル通信)
7. [ジョイスティック](#7-ジョイスティック)
8. [GPU サポート（任意）](#8-gpu-サポート任意)

---

## 1. システム要件

| 項目 | 要件 |
|---|---|
| OS | Ubuntu 20.04 / 22.04 推奨（他の Linux ディストリビューションでも動作可） |
| RAM | 8 GB 以上（RViz/Gazebo 使用時は 16 GB 推奨） |
| ストレージ | 空き 20 GB 以上 |
| その他 | Docker 20.10 以上，docker compose v2 以上 |

---

## 2. Docker のインストール

```bash
# 古いバージョンを削除（あれば）
sudo apt remove docker docker-engine docker.io containerd runc

# 必要パッケージをインストール
sudo apt update
sudo apt install -y ca-certificates curl gnupg

# Docker の公式 GPG キーを追加
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# リポジトリを追加
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Docker Engine・Compose をインストール
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 現在のユーザーを docker グループに追加（sudo なしで使えるようにする）
sudo usermod -aG docker $USER

# 変更を反映（ログアウト・ログインが必要）
newgrp docker
```

### 動作確認

```bash
docker version
docker compose version
docker run hello-world
```

---

## 3. 初回セットアップ

```bash
# リポジトリのクローン
git clone <リポジトリURL>
cd ros1_docker_ws

# イメージをビルド（数分かかります）
make build

# catkin ワークスペースを初期化
make catkin-init
```

---

## 4. GUI ツール（RViz / Gazebo）

Linux ホストでは X11 転送によりコンテナ内の GUI アプリをホストの画面に表示できます．

### 仕組み

`make up` / `make shell` / `make rviz` / `make gazebo` 実行時に `xhost +local:docker` が自動実行され，Docker コンテナからホストの X サーバーへの接続が許可されます．終了時には `xhost -local:docker` で権限を戻します．

### 起動

```bash
make rviz     # RViz を起動
make gazebo   # Gazebo を起動
```

### コンテナ内から直接起動する場合

```bash
make shell

source /opt/ros/noetic/setup.bash
rviz
```

### 表示されない場合のトラブルシューティング

```bash
# DISPLAY の確認
echo $DISPLAY   # → :0 や :1 などが表示されること

# xhost の設定確認
xhost

# 手動で許可する場合
xhost +local:docker
```

---

## 5. CAN 通信

SocketCAN ベースの CAN インターフェース（`can0` など）を使用します．  
`network_mode: host` と `privileged: true` により，ホストの CAN インターフェースをコンテナ内から直接操作できます．

> **Windows では非対応**: SocketCAN は Linux カーネルの機能のため，Windows 環境では使用できません．

### ホスト側の事前準備

USB-CAN アダプタ（Peak PCAN，Kvaser 等）を接続後，**ホスト側**でカーネルモジュールをロードします．

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

`ros_canopen` や `socketcan_bridge` パッケージが代表的です．

```bash
# socketcan_bridge を使う場合（src/ にクローンしてビルド）
cd catkin_ws/src
git clone https://github.com/ros-industrial/ros_canopen.git
make rosdep-install
make catkin-build
```

---

## 6. シリアル通信

### デバイスのパススルー設定

`docker-compose.yml` では `/dev:/dev` でホストの全デバイスをコンテナに共有しています．  
追加の設定は不要で，ホストに接続した USB シリアルデバイス（`/dev/ttyUSB0`，`/dev/ttyACM0` 等）はそのままコンテナ内から使用できます．

> コンテナ内ユーザー `ros` は `dialout` グループに所属しているため，`sudo` なしでシリアルデバイスにアクセスできます．

### 接続確認

```bash
# 接続中のシリアルデバイス一覧
make serial-list

# コンテナ内で確認する場合
make shell
ls -l /dev/ttyUSB* /dev/ttyACM*
```

### デバイス名の固定（udev ルール）

USB ポートを差し替えるたびにデバイス名が変わる場合は，udev ルールでシリアル番号に紐づけて固定できます．

```bash
# シリアル番号の確認
udevadm info -a -n /dev/ttyUSB0 | grep serial
```

`/etc/udev/rules.d/99-usb-serial.rules` に登録します．

```
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", ATTRS{serial}=="YOUR_SERIAL", SYMLINK+="ttyMYDEVICE"
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

## 7. ジョイスティック

`docker-compose.yml` では `/dev:/dev` でホストの全デバイスを共有しているため，ジョイスティックを接続するだけでコンテナ内から `/dev/input/js*` として認識されます．  
コンテナ起動時に `entrypoint.sh` がデバイスの GID を `ros` ユーザへ自動付与するため，追加の権限設定は不要です．

### 接続確認

```bash
# ホスト側でデバイスを確認
ls -l /dev/input/js*
# → /dev/input/js0, /dev/input/js1 等が表示されること

# コンテナ内でも同様に確認
make shell
ls -l /dev/input/js*
```

### joy ノードの起動

```bash
# デフォルト（/dev/input/js0）
make joy

# 別デバイスの場合
make joy JS_DEV=/dev/input/js1
```

別ターミナルでトピックを確認します．

```bash
make shell
source /opt/ros/noetic/setup.bash
rostopic echo /joy
```

### 複数のジョイスティックが接続されている場合

`js0`，`js1` のどちらが目的のデバイスかわからない場合は `jstest` で確認できます．

```bash
make shell
jstest /dev/input/js0
```

---

## 8. GPU サポート（任意）

NVIDIA GPU を使う場合は `docker-compose.yml` の `deploy` セクションをアンコメントしてください．

```yaml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

事前に `nvidia-container-toolkit` のインストールが必要です．

```bash
# nvidia-container-toolkit のインストール
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | \
  sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt update
sudo apt install -y nvidia-container-toolkit
sudo systemctl restart docker
```

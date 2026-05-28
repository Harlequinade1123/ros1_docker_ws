# ROS1 Noetic Docker ワークスペース

RViz / Gazebo 対応の ROS1 Noetic 開発環境です．  
ソースコードはホストで管理し，**実行はすべて Docker コンテナ内**で行います．  
ビルドには `catkin build`（catkin-tools）を使用し，rosbag の録画・再生にも対応しています．

---

## 対応プラットフォーム

| OS | 実行ツール | セットアップガイド |
|---|---|---|
| Ubuntu / Linux | `make` | [docs/ubuntu-setup.md](docs/ubuntu-setup.md) |
| Windows (PowerShell) | `.\run.ps1` | [docs/windows-setup.md](docs/windows-setup.md) |

---

## ディレクトリ構成

```
ros1_docker_ws/
├── catkin_ws/                    ← ホスト管理ワークスペース (Git 管理対象)
│   └── src/                      ← ここにパッケージを置く
├── bags/                         ← rosbag の保存先（コンテナ /home/ros/bags と同期）
├── docker/
│   ├── Dockerfile                ← ROS Noetic イメージ定義（両 OS 共通）
│   ├── docker-compose.yml        ← Linux 用（host ネットワーク・X11 Unix ソケット）
│   ├── docker-compose.windows.yml ← Windows 用（bridge ネットワーク・VcXsrv TCP）
│   └── entrypoint.sh             ← 起動時にジョイスティック GID 付与・setup.bash を自動 source
├── docs/
│   ├── ubuntu-setup.md           ← Ubuntu 詳細ガイド（CAN・シリアル・GUI 等）
│   └── windows-setup.md          ← Windows 詳細ガイド（usbipd・VcXsrv 等）
├── Makefile                      ← Ubuntu / Linux 用コマンド集
├── run.ps1                       ← Windows PowerShell 用コマンド集
└── .gitignore
```

---

## クイックスタート

### Ubuntu / Linux

```bash
# 1. イメージをビルド（初回のみ，数分かかります）
make build

# 2. catkin ワークスペースを初期化（初回のみ）
make catkin-init

# 3. パッケージを src/ に配置してビルド
make rosdep-install   # 依存パッケージをインストール
make catkin-build     # ビルド

# 4. コンテナに入って作業
make up               # コンテナ起動
make shell            # bash に入る
```

### Windows (PowerShell)

```powershell
# 1. イメージをビルド（初回のみ，数分かかります）
.\run.ps1 build

# 2. catkin ワークスペースを初期化（初回のみ）
.\run.ps1 catkin-init

# 3. パッケージを src\ に配置してビルド
.\run.ps1 rosdep-install   # 依存パッケージをインストール
.\run.ps1 catkin-build     # ビルド

# 4. コンテナに入って作業
.\run.ps1 up               # コンテナ起動
.\run.ps1 shell            # bash に入る
```

> 初回セットアップの詳細は各 OS のガイドを参照してください．

---

## catkin build の使い方

このワークスペースは `catkin build`（catkin-tools）を使用します．  
`catkin_make` とは異なり，並列・差分ビルドが効率的に動作します．

### コマンド一覧

| 操作 | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| ワークスペース初期化（初回のみ） | `make catkin-init` | `.\run.ps1 catkin-init` |
| 全パッケージをビルド | `make catkin-build` | `.\run.ps1 catkin-build` |
| 特定パッケージのみビルド | `make catkin-build-pkg PKG=my_pkg` | `.\run.ps1 catkin-build-pkg -PKG my_pkg` |
| ビルド成果物を削除 | `make catkin-clean` | `.\run.ps1 catkin-clean` |

### コンテナ内での操作

```bash
# 全体ビルド
catkin build

# 特定パッケージのみ
catkin build my_pkg

# ビルド状況を確認
catkin list

# 設定を確認
catkin config
```

> **注意**: `catkin_make` は使用しないでください．`.catkin_tools/` の設定が上書きされる場合があります．

---

## rosbag の使い方

`bags/` ディレクトリがホストとコンテナ間で共有されているため，  
コンテナ内で録画した bag ファイルはホストの `bags/` からそのまま参照できます．

### 録画（record）

| 操作 | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| 全トピックを録画 | `make bag-record` | `.\run.ps1 bag-record` |
| 指定トピックを録画 | `make bag-record TOPICS="/cmd_vel /odom"` | `.\run.ps1 bag-record -TOPICS "/cmd_vel /odom"` |

録画ファイルは `bags/` に `2024-01-01-12-00-00.bag` のような名前で保存されます．  
録画を止めるには **Ctrl+C** を押します．

### 再生（play）

| 操作 | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| 通常速度で再生 | `make bag-play BAG=xxx.bag` | `.\run.ps1 bag-play -BAG xxx.bag` |
| 倍速指定で再生 | `make bag-play BAG=xxx.bag RATE=0.5` | `.\run.ps1 bag-play -BAG xxx.bag -RATE 0.5` |
| メタ情報の確認 | `make bag-info BAG=xxx.bag` | `.\run.ps1 bag-info -BAG xxx.bag` |
| ファイル一覧 | `make bag-list` | `.\run.ps1 bag-list` |
| bz2 圧縮 | `make bag-compress BAG=xxx.bag` | `.\run.ps1 bag-compress -BAG xxx.bag` |

### コンテナ内での操作（共通）

```bash
# ループ再生
rosbag play --clock --loop /home/ros/bags/2024-01-01-12-00-00.bag

# 特定トピックのみ再生
rosbag play /home/ros/bags/2024-01-01-12-00-00.bag --topics /cmd_vel /odom

# use_sim_time を有効にする場合
rosparam set use_sim_time true
rosbag play --clock /home/ros/bags/2024-01-01-12-00-00.bag

# rqt_bag で GUI 操作（Ubuntu のみ）
rqt_bag /home/ros/bags/2024-01-01-12-00-00.bag
```

> `--clock` オプションを付けると `/clock` トピックが発行されます．  
> `rospy`/`roscpp` で時刻同期が必要な場合は `use_sim_time:=true` も設定してください．

---

## コマンド一覧

```bash
make help        # Ubuntu
.\run.ps1 help   # Windows
```

| コマンド | Ubuntu (make) | Windows (run.ps1) |
|---|---|---|
| イメージをビルド | `build` | `build` |
| コンテナ起動 | `up` | `up` |
| コンテナ停止 | `down` | `down` |
| コンテナに入る | `shell` | `shell` |
| 新規シェルセッション | `shell-new` | `shell-new` |
| roscore 起動 | `roscore` | `roscore` |
| catkin 初期化 | `catkin-init` | `catkin-init` |
| 全体ビルド | `catkin-build` | `catkin-build` |
| 特定パッケージビルド | `catkin-build-pkg PKG=...` | `catkin-build-pkg -PKG ...` |
| ビルド成果物削除 | `catkin-clean` | `catkin-clean` |
| 依存パッケージインストール | `rosdep-install` | `rosdep-install` |
| RViz 起動 | `rviz` | `rviz` |
| Gazebo 起動 | `gazebo` | `gazebo` |
| rosbag 録画 | `bag-record [TOPICS=...]` | `bag-record [-TOPICS ...]` |
| rosbag 再生 | `bag-play BAG=... [RATE=...]` | `bag-play -BAG ... [-RATE ...]` |
| bag メタ情報 | `bag-info BAG=...` | `bag-info -BAG ...` |
| bag 圧縮 | `bag-compress BAG=...` | `bag-compress -BAG ...` |
| bag 一覧 | `bag-list` | `bag-list` |
| ジョイスティック起動 | `joy [JS_DEV=...]` | `joy [-JsDev ...]` |
| CAN 起動 | `can-up [IFACE=...] [BITRATE=...]` | 非対応 |
| CAN 停止 | `can-down [IFACE=...]` | 非対応 |
| CAN ダンプ | `can-dump [IFACE=...]` | 非対応 |
| CAN 送信 | `can-send [IFACE=...] [ID=...] [DATA=...]` | 非対応 |
| シリアル一覧 | `serial-list` | `serial-list` |
| シリアルモニタ | `serial-monitor [PORT=...] [BAUD=...]` | `serial-monitor [-PORT ...] [-BAUD ...]` |

---

## プラットフォーム別の詳細

- **Ubuntu / Linux**: [docs/ubuntu-setup.md](docs/ubuntu-setup.md)  
  GUI (X11)・ジョイスティック・CAN 通信・シリアル通信・GPU サポート

- **Windows**: [docs/windows-setup.md](docs/windows-setup.md)  
  Docker Desktop・VcXsrv・usbipd-win・ジョイスティック・シリアル通信・トラブルシューティング

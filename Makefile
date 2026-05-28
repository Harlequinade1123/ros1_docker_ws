# ================================================================
#  ROS1 Noetic - Docker ワークフロー Makefile
# ================================================================
IMAGE   := ros1_noetic_ws:latest
COMPOSE := docker compose -f docker/docker-compose.yml
RUN     := $(COMPOSE) run --rm ros

.PHONY: build up down shell shell-new \
        catkin-init catkin-build catkin-clean catkin-build-pkg \
        joy roscore rviz gazebo \
        rosdep-install \
        bag-record bag-play bag-info bag-compress bag-list \
        can-up can-down can-dump can-send can-status \
        serial-list serial-monitor \
        help

# ── Docker ──────────────────────────────────────────────────────
build:          ## イメージをビルド
	$(COMPOSE) build

up:             ## コンテナをバックグラウンドで起動
	xhost +local:docker
	$(COMPOSE) up -d

down:           ## コンテナを停止・削除
	$(COMPOSE) down
	xhost -local:docker

shell:          ## 実行中コンテナに bash で入る
	xhost +local:docker
	docker exec -it -u ros ros1_ws bash

shell-new:      ## 新しいシェルセッションをコンテナで開く
	xhost +local:docker
	$(RUN) bash

# ── catkin ──────────────────────────────────────────────────────
catkin-init:    ## catkin ワークスペースを初期化 (初回のみ)
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   catkin init && \
	   catkin config \
	     --extend /opt/ros/noetic \
	     --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo"

catkin-build:   ## ワークスペース全体をビルド
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   catkin build"

catkin-build-pkg: ## 特定パッケージだけビルド (例: make catkin-build-pkg PKG=my_pkg)
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   catkin build $(PKG)"

catkin-clean:   ## ビルド成果物を削除
	$(RUN) bash -c \
	  "catkin clean -y"

# ── rosdep ──────────────────────────────────────────────────────
rosdep-install: ## src/ 以下の依存パッケージを自動インストール
	$(RUN) bash -c \
	  "cd /home/ros/catkin_ws && \
	   rosdep install --from-paths src --ignore-src -r -y"

# ── GUI ─────────────────────────────────────────────────────────
joy:            ## ジョイスティックノードを起動 (JS_DEV=/dev/input/js0)
	xhost +local:docker
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   rosrun joy joy_node _dev:=$(JS_DEV)"

roscore:        ## roscore を起動
	xhost +local:docker
	$(COMPOSE) --profile with-roscore up roscore

rviz:           ## RViz を起動
	xhost +local:docker
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   source /home/ros/catkin_ws/devel/setup.bash 2>/dev/null || true && \
	   rviz"

gazebo:         ## Gazebo を起動
	xhost +local:docker
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   roslaunch gazebo_ros empty_world.launch"

# ── rosbag ──────────────────────────────────────────────────────
# 使用例:
#   make bag-record TOPICS="/cmd_vel /odom /scan"
#   make bag-record TOPICS="-a"              # 全トピック
#   make bag-play   BAG=2024-01-01-12-00.bag
#   make bag-play   BAG=2024-01-01-12-00.bag RATE=0.5
#   make bag-info   BAG=2024-01-01-12-00.bag
#   make bag-compress BAG=2024-01-01-12-00.bag

TOPICS   ?= -a
BAG      ?=
RATE     ?= 1.0
BAG_DIR  := /home/ros/bags

bag-record:     ## rosbag を録画 (TOPICS="-a" or TOPICS="/topic1 /topic2")
	@test -n "$(TOPICS)" || (echo "Usage: make bag-record TOPICS='/topic1 /topic2'" && exit 1)
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   mkdir -p $(BAG_DIR) && \
	   rosbag record -o $(BAG_DIR)/ $(TOPICS)"

bag-play:       ## rosbag を再生 (BAG=ファイル名 [RATE=0.5])
	@test -n "$(BAG)" || (echo "Usage: make bag-play BAG=filename.bag [RATE=0.5]" && exit 1)
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   rosbag play --clock -r $(RATE) $(BAG_DIR)/$(BAG)"

bag-info:       ## rosbag のメタ情報を表示 (BAG=ファイル名)
	@test -n "$(BAG)" || (echo "Usage: make bag-info BAG=filename.bag" && exit 1)
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   rosbag info $(BAG_DIR)/$(BAG)"

bag-compress:   ## rosbag を bz2 圧縮 (BAG=ファイル名)
	@test -n "$(BAG)" || (echo "Usage: make bag-compress BAG=filename.bag" && exit 1)
	$(RUN) bash -c \
	  "source /opt/ros/noetic/setup.bash && \
	   rosbag compress --bz2 $(BAG_DIR)/$(BAG)"

bag-list:       ## bags/ ディレクトリのファイル一覧を表示
	$(RUN) bash -c \
	  "ls -lh $(BAG_DIR)/*.bag 2>/dev/null || echo '(bag ファイルがありません)'"

# ── CAN 通信 ────────────────────────────────────────────────────
# 使用例:
#   make can-up   IFACE=can0 BITRATE=1000000
#   make can-down IFACE=can0
#   make can-dump IFACE=can0
#   make can-send IFACE=can0 ID=123 DATA="11 22 33"

JS_DEV  ?= /dev/input/js0

IFACE   ?= can0
BITRATE ?= 1000000
ID      ?= 123
DATA    ?= 00 00 00 00

can-up:         ## CAN インターフェースを起動 (IFACE=can0 BITRATE=1000000)
	$(RUN) bash -c \
	  "ip link set $(IFACE) type can bitrate $(BITRATE) && \
	   ip link set $(IFACE) up && \
	   echo '✓ $(IFACE) up @ $(BITRATE) bps'"

can-down:       ## CAN インターフェースを停止 (IFACE=can0)
	$(RUN) bash -c \
	  "ip link set $(IFACE) down && echo '✓ $(IFACE) down'"

can-status:     ## CAN インターフェースの状態を表示
	$(RUN) bash -c \
	  "ip -details -statistics link show $(IFACE)"

can-dump:       ## CAN フレームをダンプ表示 (IFACE=can0)
	$(RUN) bash -c \
	  "candump $(IFACE)"

can-send:       ## CAN フレームを1回送信 (IFACE=can0 ID=123 DATA="11 22 33")
	$(RUN) bash -c \
	  "cansend $(IFACE) $(ID)#$(shell echo '$(DATA)' | tr ' ' '')"

# ── シリアル通信 ─────────────────────────────────────────────────
# 使用例:
#   make serial-list
#   make serial-monitor PORT=/dev/ttyUSB0 BAUD=115200

PORT    ?= /dev/ttyUSB0
BAUD    ?= 115200

serial-list:    ## 接続されているシリアルデバイスを一覧表示
	$(RUN) bash -c \
	  "ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null || echo '(デバイスが見つかりません)'"

serial-monitor: ## シリアルモニタを開く (PORT=/dev/ttyUSB0 BAUD=115200)
	$(RUN) bash -c \
	  "minicom -D $(PORT) -b $(BAUD)"

# ── ヘルプ ──────────────────────────────────────────────────────
help:           ## このヘルプを表示
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-22s\033[0m %s\n", $$1, $$2}'

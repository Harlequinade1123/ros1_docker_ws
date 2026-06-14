# ================================================================
#  ROS1 Noetic Docker Workspace
# ================================================================
COMPOSE := docker compose -f docker/docker-compose.yml
EXEC    := $(COMPOSE) exec -u ros ros bash -c

.DEFAULT_GOAL := help

.PHONY: build up down shell shell-new \
        catkin-init catkin-build catkin-clean catkin-build-pkg \
        joy roscore rviz gazebo \
        rosdep-install \
        bag-record bag-play bag-info bag-compress bag-list \
        can-up can-down can-dump can-send can-status \
        serial-list serial-monitor \
        help

# ── Docker ──────────────────────────────────────────────────────
build:          ## Build the Docker image
	$(COMPOSE) build

up:             ## Start the container in the background
	mkdir -p catkin_ws/src bags
	xhost +local:docker 2>/dev/null || true
	$(COMPOSE) up -d

down:           ## Stop and remove the container
	$(COMPOSE) down
	xhost -local:docker 2>/dev/null || true

shell:          ## Open a bash shell in the running container
	$(COMPOSE) exec -u ros ros bash

shell-new:      ## Open an additional bash shell in the running container
	docker exec -it -u ros ros1_ws bash

# ── catkin ──────────────────────────────────────────────────────
catkin-init:    ## Initialize the catkin workspace (first time only)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   catkin init && \
	   catkin config \
	     --extend /opt/ros/noetic \
	     --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo"

catkin-build:   ## Build all packages in the workspace
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   catkin build"

catkin-build-pkg: ## Build a specific package  (make catkin-build-pkg PKG=my_pkg)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   catkin build $(PKG)"

catkin-clean:   ## Remove build artifacts
	$(EXEC) "catkin clean -y"

# ── rosdep ──────────────────────────────────────────────────────
rosdep-install: ## Install dependencies declared in src/
	$(EXEC) \
	  "cd /home/ros/catkin_ws && \
	   rosdep install --from-paths src --ignore-src -r -y"

# ── GUI ─────────────────────────────────────────────────────────
joy:            ## Launch joy_node  (JS_DEV=/dev/input/js0)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   rosrun joy joy_node _dev:=$(JS_DEV)"

roscore:        ## Start roscore inside the container
	$(EXEC) "source /opt/ros/noetic/setup.bash && roscore"

rviz:           ## Launch RViz
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   source /home/ros/catkin_ws/devel/setup.bash 2>/dev/null || true && \
	   rviz"

gazebo:         ## Launch Gazebo
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   roslaunch gazebo_ros empty_world.launch"

# ── rosbag ──────────────────────────────────────────────────────
# Examples:
#   make bag-record TOPICS="/cmd_vel /odom /scan"
#   make bag-record TOPICS="-a"              # all topics
#   make bag-play   BAG=2024-01-01-12-00.bag
#   make bag-play   BAG=2024-01-01-12-00.bag RATE=0.5
#   make bag-info   BAG=2024-01-01-12-00.bag
#   make bag-compress BAG=2024-01-01-12-00.bag

TOPICS   ?= -a
BAG      ?=
RATE     ?= 1.0
BAG_DIR  := /home/ros/bags

bag-record:     ## Record topics  (TOPICS="-a" or TOPICS="/topic1 /topic2")
	@test -n "$(TOPICS)" || (echo "Usage: make bag-record TOPICS='/topic1 /topic2'" && exit 1)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   mkdir -p $(BAG_DIR) && \
	   rosbag record -o $(BAG_DIR)/ $(TOPICS)"

bag-play:       ## Play a bag file  (BAG=filename [RATE=0.5])
	@test -n "$(BAG)" || (echo "Usage: make bag-play BAG=filename.bag [RATE=0.5]" && exit 1)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   rosbag play --clock -r $(RATE) $(BAG_DIR)/$(BAG)"

bag-info:       ## Show bag metadata  (BAG=filename)
	@test -n "$(BAG)" || (echo "Usage: make bag-info BAG=filename.bag" && exit 1)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   rosbag info $(BAG_DIR)/$(BAG)"

bag-compress:   ## Compress a bag file with bz2  (BAG=filename)
	@test -n "$(BAG)" || (echo "Usage: make bag-compress BAG=filename.bag" && exit 1)
	$(EXEC) \
	  "source /opt/ros/noetic/setup.bash && \
	   rosbag compress --bz2 $(BAG_DIR)/$(BAG)"

bag-list:       ## List bag files in bags/
	$(EXEC) \
	  "ls -lh $(BAG_DIR)/*.bag 2>/dev/null || echo '(no bag files found)'"

# ── CAN ─────────────────────────────────────────────────────────
# Examples:
#   make can-up   IFACE=can0 BITRATE=1000000
#   make can-down IFACE=can0
#   make can-dump IFACE=can0
#   make can-send IFACE=can0 ID=123 DATA=11.22.33.44

JS_DEV  ?= /dev/input/js0

IFACE   ?= can0
BITRATE ?= 1000000
ID      ?= 123
DATA    ?= 11.22.33.44

can-up:         ## Bring up a CAN interface  (IFACE=can0 BITRATE=1000000)
	$(EXEC) \
	  "sudo ip link set $(IFACE) type can bitrate $(BITRATE) && \
	   sudo ip link set $(IFACE) up && \
	   echo '$(IFACE) up @ $(BITRATE) bps'"

can-down:       ## Bring down a CAN interface  (IFACE=can0)
	$(EXEC) \
	  "sudo ip link set $(IFACE) down && echo '$(IFACE) down'"

can-status:     ## Show CAN interface status
	$(EXEC) \
	  "ip -details -statistics link show $(IFACE)"

can-dump:       ## Dump CAN frames  (IFACE=can0)
	$(EXEC) "sudo candump $(IFACE)"

can-send:       ## Send a CAN frame  (IFACE=can0 ID=123 DATA=11.22.33.44)
	$(EXEC) "sudo cansend $(IFACE) $(ID)#$(DATA)"

# ── Serial ──────────────────────────────────────────────────────
# Examples:
#   make serial-list
#   make serial-monitor PORT=/dev/ttyUSB0 BAUD=115200

PORT    ?= /dev/ttyUSB0
BAUD    ?= 115200

serial-list:    ## List connected serial devices
	$(EXEC) \
	  "ls -l /dev/ttyUSB* /dev/ttyACM* /dev/ttyS* 2>/dev/null || echo '(no serial devices found)'"

serial-monitor: ## Open serial monitor  (PORT=/dev/ttyUSB0 BAUD=115200)
	$(EXEC) \
	  "minicom -D $(PORT) -b $(BAUD)"

# ── Help ────────────────────────────────────────────────────────
help:           ## Show this help
	@echo ""
	@echo "\033[1mROS1 Noetic Docker Development Environment\033[0m"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-22s\033[0m %s\n", $$1, $$2}'
	@echo ""

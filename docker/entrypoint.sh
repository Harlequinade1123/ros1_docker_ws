#!/bin/bash
# コンテナ起動時に ROS 環境を自動セットアップするエントリーポイント

set -e

source /opt/ros/noetic/setup.bash

# catkin ワークスペースが devel/ を持っていれば source
if [ -f "/home/ros/catkin_ws/devel/setup.bash" ]; then
  source /home/ros/catkin_ws/devel/setup.bash
fi

exec "$@"

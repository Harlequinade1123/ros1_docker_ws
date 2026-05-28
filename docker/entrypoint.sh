#!/bin/bash
# コンテナ起動時に ROS 環境を自動セットアップするエントリーポイント
# root で実行し，デバイスグループを動的に付与してから gosu で ros ユーザへ移行する

set -e

# /dev/input/js* デバイスの GID を ros ユーザに動的付与
# （ホストの input グループ GID とコンテナの GID が異なる場合でも対応）
for JS in /dev/input/js*; do
  [ -c "$JS" ] || continue
  JS_GID=$(stat -c %g "$JS")
  getent group "$JS_GID" >/dev/null 2>&1 || groupadd -g "$JS_GID" "input_host" 2>/dev/null || true
  id -G ros 2>/dev/null | tr ' ' '\n' | grep -qx "$JS_GID" || \
    usermod -aG "$JS_GID" ros 2>/dev/null || true
done

source /opt/ros/noetic/setup.bash

if [ -f "/home/ros/catkin_ws/devel/setup.bash" ]; then
  source /home/ros/catkin_ws/devel/setup.bash
fi

exec gosu ros "$@"

#!/bin/bash
# Entrypoint: runs as root, dynamically assigns device GIDs, then drops to the ros user via gosu

set -e

# Dynamically assign host joystick GID to the ros user so it can access /dev/input/js*
# even when the host input group GID differs from the container's GID
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

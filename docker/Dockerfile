FROM ros:noetic-ros-base-focal

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── 基本ツール & GUI サポート ──────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # ビルドツール
    python3-catkin-tools \
    python3-rosdep \
    python3-pip \
    build-essential \
    cmake \
    git \
    curl \
    # GUI / RViz / Gazebo
    ros-noetic-rviz \
    ros-noetic-gazebo-ros-pkgs \
    ros-noetic-gazebo-ros-control \
    ros-noetic-rqt \
    ros-noetic-rqt-common-plugins \
    # rosbag / トピック解析
    ros-noetic-rosbag \
    ros-noetic-rosbag-storage \
    ros-noetic-rqt-bag \
    ros-noetic-rqt-bag-plugins \
    ros-noetic-rosbash \
    python3-rosbag \
    # CAN 通信
    can-utils \
    iproute2 \
    libsocketcan-dev \
    libsocketcan2 \
    # シリアル通信
    python3-serial \
    minicom \
    setserial \
    usbutils \
    # X11 forwarding
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    x11-apps \
    mesa-utils \
    # その他
    tmux \
    vim \
    bash-completion \
  && rm -rf /var/lib/apt/lists/*

# ── rosdep 初期化 ──────────────────────────────────────────────────
RUN rosdep init || true && rosdep update

# ── ワークスペースのセットアップ ──────────────────────────────────
ARG WORKSPACE=/home/ros/catkin_ws
ENV WORKSPACE=${WORKSPACE}

RUN useradd -m -s /bin/bash ros && \
    mkdir -p ${WORKSPACE}/src && \
    usermod -aG dialout ros && \
    chown -R ros:ros /home/ros

USER ros
WORKDIR ${WORKSPACE}

# ── catkin build のデフォルト設定 ────────────────────────────────
RUN mkdir -p ${WORKSPACE}/src && \
    bash -c "source /opt/ros/noetic/setup.bash && \
             catkin config \
               --workspace ${WORKSPACE} \
               --extend /opt/ros/noetic \
               --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo" || true

# ── rosbag 保存ディレクトリ ──────────────────────────────────────
RUN mkdir -p /home/ros/bags

# ── bashrc に自動 source ───────────────────────────────────────────
RUN echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "[ -f ${WORKSPACE}/devel/setup.bash ] && source ${WORKSPACE}/devel/setup.bash" >> ~/.bashrc && \
    echo "export ROS_HOSTNAME=localhost" >> ~/.bashrc && \
    echo "export ROS_MASTER_URI=http://localhost:11311" >> ~/.bashrc && \
    echo "export ROSBAG_DIR=/home/ros/bags" >> ~/.bashrc && \
    echo "alias bag-record='rosbag record -o \${ROSBAG_DIR}/'" >> ~/.bashrc && \
    echo "alias bag-play='rosbag play'" >> ~/.bashrc && \
    echo "alias bag-info='rosbag info'" >> ~/.bashrc && \
    echo "# CAN ヘルパー" >> ~/.bashrc && \
    echo "alias can-status='ip -details -statistics link show'" >> ~/.bashrc && \
    echo "alias can-dump='candump'" >> ~/.bashrc && \
    echo "# シリアルヘルパー" >> ~/.bashrc && \
    echo "alias serial-list='ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'" >> ~/.bashrc

CMD ["/bin/bash"]

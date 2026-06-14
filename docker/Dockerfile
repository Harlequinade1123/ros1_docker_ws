FROM ros:noetic-ros-base-focal

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# ── Base tools & GUI support ──────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
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
    # rosbag / topic inspection
    ros-noetic-rosbag \
    ros-noetic-rosbag-storage \
    ros-noetic-rqt-bag \
    ros-noetic-rqt-bag-plugins \
    ros-noetic-rosbash \
    python3-rosbag \
    # CAN
    can-utils \
    iproute2 \
    libsocketcan-dev \
    libsocketcan2 \
    # Serial
    python3-serial \
    minicom \
    setserial \
    usbutils \
    # X11 forwarding
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    x11-apps \
    mesa-utils \
    # URDF / xacro / robot models
    ros-noetic-xacro \
    ros-noetic-urdf \
    ros-noetic-robot-state-publisher \
    ros-noetic-joint-state-publisher \
    ros-noetic-joint-state-publisher-gui \
    # TF
    ros-noetic-tf \
    ros-noetic-tf2-ros \
    ros-noetic-tf2-tools \
    # ros_control
    ros-noetic-ros-control \
    ros-noetic-ros-controllers \
    # geometry
    ros-noetic-geometry \
    # Actions / dynamic reconfigure
    ros-noetic-actionlib \
    ros-noetic-dynamic-reconfigure \
    # Testing
    ros-noetic-rostest \
    # Teleoperation
    ros-noetic-joy \
    # Image / point cloud
    ros-noetic-image-transport \
    ros-noetic-image-proc \
    ros-noetic-image-geometry \
    ros-noetic-cv-bridge \
    ros-noetic-pcl-ros \
    ros-noetic-nodelet \
    # LiDAR
    ros-noetic-laser-geometry \
    ros-noetic-laser-filters \
    # Utilities
    ros-noetic-angles \
    ros-noetic-filters \
    ros-noetic-pluginlib \
    # Tutorials
    ros-noetic-turtlesim \
    # Visualization helpers
    ros-noetic-rqt-graph \
    ros-noetic-rqt-tf-tree \
    # Workspace management
    python3-vcstool \
    python3-wstool \
    # Misc
    tmux \
    vim \
    bash-completion \
    htop \
    net-tools \
    wget \
    jq \
  && rm -rf /var/lib/apt/lists/*

# ── rosdep init ───────────────────────────────────────────────────
RUN rosdep init || true && rosdep update

# ── Workspace setup ───────────────────────────────────────────────
ARG WORKSPACE=/home/ros/catkin_ws
ENV WORKSPACE=${WORKSPACE}

RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo \
    gosu \
  && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash ros && \
    mkdir -p ${WORKSPACE}/src && \
    usermod -aG dialout,plugdev ros && \
    echo "ros ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    chown -R ros:ros /home/ros

USER ros
WORKDIR ${WORKSPACE}

# ── catkin build defaults ─────────────────────────────────────────
RUN mkdir -p ${WORKSPACE}/src && \
    bash -c "source /opt/ros/noetic/setup.bash && \
             catkin config \
               --workspace ${WORKSPACE} \
               --extend /opt/ros/noetic \
               --cmake-args -DCMAKE_BUILD_TYPE=RelWithDebInfo"

# ── rosbag storage directory ──────────────────────────────────────
RUN mkdir -p /home/ros/bags

# ── bashrc auto-source ────────────────────────────────────────────
RUN echo "[ -f /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion" >> ~/.bashrc && \
    echo "source /opt/ros/noetic/setup.bash" >> ~/.bashrc && \
    echo "[ -f ${WORKSPACE}/devel/setup.bash ] && source ${WORKSPACE}/devel/setup.bash" >> ~/.bashrc && \
    echo 'export ROS_HOSTNAME=${ROS_HOSTNAME:-localhost}' >> ~/.bashrc && \
    echo 'export ROS_MASTER_URI=${ROS_MASTER_URI:-http://localhost:11311}' >> ~/.bashrc && \
    echo "export ROSBAG_DIR=/home/ros/bags" >> ~/.bashrc && \
    echo "alias bag-record='rosbag record -o \${ROSBAG_DIR}/'" >> ~/.bashrc && \
    echo "alias bag-play='rosbag play'" >> ~/.bashrc && \
    echo "alias bag-info='rosbag info'" >> ~/.bashrc && \
    echo "# CAN helpers" >> ~/.bashrc && \
    echo "alias can-status='ip -details -statistics link show'" >> ~/.bashrc && \
    echo "alias can-dump='candump'" >> ~/.bashrc && \
    echo "# Serial helpers" >> ~/.bashrc && \
    echo "alias serial-list='ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null'" >> ~/.bashrc

# Entrypoint: runs as root, assigns device GIDs, then drops to ros user via gosu
USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]

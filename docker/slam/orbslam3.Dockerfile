FROM indoor-pathfinding-ros2-base:latest

ARG DEBIAN_FRONTEND=noninteractive

# NVIDIA CUDA Toolkit 12.2
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget ca-certificates gnupg && \
    wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
    dpkg -i cuda-keyring_1.1-1_all.deb && rm -f cuda-keyring_1.1-1_all.deb && \
    apt-get update && apt-get install -y --no-install-recommends cuda-toolkit-12-2 && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/usr/local/cuda-12.2/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda-12.2/lib64:${LD_LIBRARY_PATH}"

# ORB-SLAM3 의존성
RUN apt-get update && apt-get install -y \
    unzip \
    pkg-config \
    python3-dev \
    python3-numpy \
    libgl1-mesa-dev \
    libglew-dev \
    libeigen3-dev \
    libpython3-dev \
    # OpenCV 빌드
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstreamer1.0-dev \
    libgtk-3-dev \
    # ROS2 패키지
    ros-humble-pcl-ros \
    ros-humble-cv-bridge \
    ros-humble-image-transport \
    ros-humble-image-common \
    ros-humble-vision-opencv \
    && rm -rf /var/lib/apt/lists/*

# OpenCV 4.4.0 (ORB-SLAM3 호환)
RUN cd /tmp && git clone https://github.com/opencv/opencv.git && \
    cd opencv && git checkout 4.4.0 && mkdir build && cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release \
          -D BUILD_EXAMPLES=OFF \
          -D BUILD_DOCS=OFF \
          -D BUILD_PERF_TESTS=OFF \
          -D BUILD_TESTS=OFF \
          -D WITH_CUDA=ON \
          -D CMAKE_INSTALL_PREFIX=/usr/local .. && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/opencv

# Pangolin (SLAM 시각화)
RUN cd /tmp && git clone https://github.com/stevenlovegrove/Pangolin && \
    cd Pangolin && git checkout v0.9.1 && mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_FLAGS=-std=c++14 \
          -DCMAKE_INSTALL_PREFIX=/usr/local .. && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/Pangolin && ldconfig

# ORB-SLAM3 소스 빌드
WORKDIR /home/orb
RUN git clone https://github.com/UZ-SLAMLab/ORB_SLAM3.git && \
    cd ORB_SLAM3 && mkdir -p build && \
    . /opt/ros/humble/setup.sh && ./build.sh

# ORB-SLAM3 ROS2 래퍼 (suchetanrs)
RUN mkdir -p /root/colcon_ws/src && \
    cd /root/colcon_ws/src && \
    git clone https://github.com/suchetanrs/ORB-SLAM3-ROS2-Docker.git orbslam3_ws && \
    cp -r orbslam3_ws/orb_slam3_ros2_wrapper . && \
    cp -r orbslam3_ws/slam_msgs . && \
    rm -rf orbslam3_ws

# colcon 빌드
RUN . /opt/ros/humble/setup.sh && \
    cd /root/colcon_ws && \
    colcon build --symlink-install

# SLAM 어댑터 (직접 작성한 코드)
COPY server/slam/ /workspace/src/slam/

# 빌드 캐시 정리
RUN rm -rf /home/orb/ORB_SLAM3/build /root/colcon_ws/build /root/colcon_ws/log

CMD ["bash", "-c", ". /opt/ros/humble/setup.sh && . /root/colcon_ws/install/setup.sh && gateway"]

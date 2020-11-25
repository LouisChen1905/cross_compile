# This Dockerfile describes a simple image with rosdep installed.
# When `run`, it outputs a script for installing dependencies for a given workspace
# Requirements:
#  * mount a colcon workspace at /ws
#  * see gather_rosdeps.sh for all-caps required input environment
FROM ubuntu:bionic

SHELL ["/bin/bash", "-c"]
RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak
RUN echo $'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse \n\
      deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse \n\
      deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu bionic-updates main restricted universe multiverse \n\
      deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse \n\
      deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse \n\
      deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse \n\
      deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse \n\
      deb-src http://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse' > /etc/apt/sources.list
RUN apt-get update && apt-get install --no-install-recommends -y \
      dirmngr \
      gnupg \
      gnupg2 \
      curl \
      sudo \
      net-tools \
      apt-transport-https \
    && rm -rf /var/lib/apt/lists/*
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
#RUN echo "deb http://packages.ros.org/ros/ubuntu bionic main" > /etc/apt/sources.list.d/ros-latest.list
RUN mkdir -p /etc/apt/sources.list.d/
RUN echo $'deb http://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu bionic main' > /etc/apt/sources.list.d/ros2-latest.list
ENV http_proxy "http://127.0.0.1:1081"
ENV https_proxy "http://127.0.0.1:1081"
ENV socks_proxy "socks://127.0.0.1:1080"
#RUN curl -s 'https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc' | apt-key add -
RUN apt-get update && apt-get install --no-install-recommends -y \
      python-rosdep \
      python3-colcon-common-extensions \
    && rm -rf /var/lib/apt/lists/*

RUN rosdep init
COPY gather_rosdeps.sh /root/
RUN mkdir -p /ws
WORKDIR /ws
ENTRYPOINT ["/root/gather_rosdeps.sh"]

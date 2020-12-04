# This file describes an image that has everything necessary installed to build a target ROS workspace
# It uses QEmu user-mode emulation to perform dependency installation and build
# Assumptions: qemu-user-static directory is present in docker build context

ARG BASE_IMAGE
FROM ${BASE_IMAGE}

ARG ROS_VERSION

SHELL ["/bin/bash", "-c"]

COPY bin/* /usr/bin/
COPY pip.conf /etc/pip.conf

# Set timezone
RUN echo 'Etc/UTC' > /etc/timezone && \
    ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

ENV http_proxy "http://127.0.0.1:1081"
ENV https_proxy "http://127.0.0.1:1081"
ENV socks_proxy "socks://127.0.0.1:1080"
RUN echo $'APT::Acquire::Retries \"3\";' > /etc/apt/apt.conf.d/80-retries

RUN mv /etc/apt/sources.list /etc/apt/sources.list.bak
RUN echo $'deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic main restricted universe multiverse \n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-updates main restricted universe multiverse \n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-backports main restricted universe multiverse \n\
deb http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports/ bionic-security main restricted universe multiverse ' > /etc/apt/sources.list

RUN apt-get update && apt-get install --no-install-recommends -y \
        tzdata \
        locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && \
    locale-gen && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LC_ALL C.UTF-8

# Add the ros apt repo
RUN apt-get update && apt-get install --no-install-recommends -y \
        dirmngr \
        gnupg2 \
        lsb-release \
        curl \
        net-tools \
        apt-transport-https \
    && rm -rf /var/lib/apt/lists/*
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' \
    --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
#RUN echo "deb http://packages.ros.org/${ROS_VERSION}/ubuntu `lsb_release -cs` main" \
    #> /etc/apt/sources.list.d/${ROS_VERSION}-latest.list
RUN mkdir -p /etc/apt/sources.list.d/
RUN echo $'deb http://mirrors.tuna.tsinghua.edu.cn/ros2/ubuntu bionic main' > /etc/apt/sources.list.d/${ROS_VERSION}-latest.list
#RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -

# ROS dependencies
RUN apt-get update && apt-get install --no-install-recommends -y \
      build-essential \
      cmake \
      python3-colcon-common-extensions \
      python3-colcon-mixin \
      python3-dev \
      python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install -U \
    setuptools

RUN pip3 install -i http://mirrors.aliyun.com/pypi/simple --no-cache-dir
#RUN pip3 config set install.trusted-host mirrors.aliyun.com


# Install some pip packages needed for testing ROS 2
RUN if [[ "${ROS_VERSION}" == "ros2" ]]; then \
    python3 -m pip install -U \
    flake8 \
    flake8-blind-except \
    flake8-builtins \
    flake8-class-newline \
    flake8-comprehensions \
    flake8-deprecated \
    flake8-docstrings \
    flake8-import-order \
    flake8-quotes \
    pytest-repeat \
    pytest-rerunfailures \
    pytest \
    pytest-cov \
    pytest-runner \
  ; fi

# Install Fast-RTPS dependencies for ROS 2
RUN if [[ "${ROS_VERSION}" == "ros2" ]]; then \
    apt-get update && apt-get install --no-install-recommends -y \
        libasio-dev \
        libtinyxml2-dev \
    && rm -rf /var/lib/apt/lists/* \
  ; fi

# Install googletest
RUN apt-get update && apt-get install -y \
    pkg-config \
    git \
    g++ \
    cmake \
    libxml2-utils \
    libgtkmm-3.0-dev \
    libgtksourceviewmm-3.0-dev \
    libpqxx-dev \
    libgraphicsmagick++1-dev \
    libboost-python-dev \
    libboost-filesystem-dev

RUN  git clone https://github.com/google/googletest.git /googletest \
    && mkdir -p /googletest/build \
    && cd /googletest/build \
    && cmake -DBUILD_SHARED_LIBS=ON .. && make && make install && ldconfig \
    && cd / && rm -rf /googletest

# Run arbitrary user setup (copy data and run script)
COPY user-custom-data/ custom-data/
COPY user-custom-setup .
RUN chmod +x ./user-custom-setup && \
    ./user-custom-setup && \
    rm -rf /var/lib/apt/lists/*

# Use generated rosdep installation script
COPY install_rosdeps.sh .
RUN chmod +x install_rosdeps.sh
RUN apt-get update && \
    ./install_rosdeps.sh && \
    rm -rf /var/lib/apt/lists/*

RUN ldconfig -p | grep gtest

# Set up build tools for the workspace
COPY mixins/ mixins/
RUN colcon mixin add cc_mixin file://$(pwd)/mixins/index.yaml && colcon mixin update cc_mixin
# In case the workspace did not actually install any dependencies, add these for uniformity
COPY build_workspace.sh /root
WORKDIR /ros_ws

ENTRYPOINT ["/root/build_workspace.sh"]

# Image args should come at the beginning.
ARG BASE_IMAGE=ubuntu:22.04
FROM $BASE_IMAGE AS dev
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG ROS_DISTRO=humble

## Install apt packages
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends \
  git \
  ssh \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Copy files
COPY autoware.repos setup-dev-env.sh ansible-galaxy-requirements.yaml amd64.env arm64.env /autoware/
COPY ansible/ /autoware/ansible/
WORKDIR /autoware

## Add GitHub to known hosts for private repositories
RUN mkdir -p ~/.ssh \
  && ssh-keyscan github.com >> ~/.ssh/known_hosts \
  && ./setup-dev-env.sh -y \
  && pip uninstall -y ansible ansible-core \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf autoware/

WORKDIR /

## Clean up unnecessary files
RUN rm -rf \
  "$HOME"/.cache \
  /etc/apt/sources.list.d/cuda*.list \
  /etc/apt/sources.list.d/docker.list \
  /etc/apt/sources.list.d/nvidia-docker.list

## Register Vulkan GPU vendors
RUN curl https://gitlab.com/nvidia/container-images/vulkan/raw/dc389b0445c788901fda1d85be96fd1cb9410164/nvidia_icd.json -o /etc/vulkan/icd.d/nvidia_icd.json \
  && chmod 644 /etc/vulkan/icd.d/nvidia_icd.json \
  && curl https://gitlab.com/nvidia/container-images/opengl/raw/5191cf205d3e4bb1150091f9464499b076104354/glvnd/runtime/10_nvidia.json -o /etc/glvnd/egl_vendor.d/10_nvidia.json \
  && chmod 644 /etc/glvnd/egl_vendor.d/10_nvidia.json \
  && mkdir -p /etc/OpenCL/vendors \
  && echo "libnvidia-opencl.so.1" > /etc/OpenCL/vendors/nvidia.icd \
  && chmod 644 /etc/OpenCL/vendors/nvidia.icd

## TODO: remove/re-evaluate after Ubuntu 24.04 is released
## Fix OpenGL issues (e.g. black screen in rviz2) due to old mesa lib in Ubuntu 22.04
## See https://github.com/autowarefoundation/autoware.universe/issues/2789
# hadolint ignore=DL3008
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y software-properties-common \
  && apt-add-repository ppa:kisak/kisak-mesa \
  && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
  libegl-mesa0 libegl1-mesa-dev libgbm-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libglx-mesa0 \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

## Create entrypoint
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" > /etc/bash.bashrc
CMD ["/bin/bash"]

FROM dev AS builder
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#!/bin/bash
# shellcheck disable=SC1090,SC1091
set -e

# hadolint ignore=SC1090
source "/opt/ros/$ROS_DISTRO/setup.bash"
source /autoware/install/setup.bash
exec "$@"

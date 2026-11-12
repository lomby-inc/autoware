#!/usr/bin/env bash
#
# Update only the LOMBY simulation sensor-kit and individual-params
# repositories with "git pull --ff-only", then rebuild the affected packages.
#
# The rest of the workspace is not updated or rebuilt.
#
# Usage:
#   ./update_lomby_sim_packages.sh [options] [WORKSPACE]
#
# Options:
#   -h, --help           Show this help.
#   -n, --dry-run        Validate and show the plan without making changes.
#       --skip-deps      Skip dependency installation with rosdep.
#       --rosdep-update  Run "rosdep update" before installing dependencies.
#   -w, --workspace DIR  Workspace root. Defaults to the script directory.
#
# Examples:
#   ./update_lomby_sim_packages.sh
#   ./update_lomby_sim_packages.sh ~/autoware
#   ./update_lomby_sim_packages.sh --dry-run ~/autoware
#
# The workspace must already be built once, because this script only rebuilds
# the selected packages and relies on their dependencies being in install/.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPO_KEYS=(
  "lomby_autoware/sensor_kit/lomby_sim_sensor_kit_launch"
  "param/lomby_autoware_individual_params"
)

PACKAGES=(
  "lomby_sim_sensor_kit_launch"
  "lomby_sim_sensor_kit_description"
  "common_lomby_sim_sensor_launch"
  "lomby_individual_params"
)

DRY_RUN=false
SKIP_DEPS=false
ROSDEP_UPDATE=false
WORKSPACE=""

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: update_lomby_sim_packages.sh [options] [WORKSPACE]

Update only the LOMBY simulation sensor-kit and individual-params
repositories with "git pull --ff-only", then rebuild the affected packages.

Options:
  -h, --help           Show this help.
  -n, --dry-run        Validate and show the plan without making changes.
      --skip-deps      Skip dependency installation with rosdep.
      --rosdep-update  Run "rosdep update" before installing dependencies.
  -w, --workspace DIR  Workspace root. Defaults to the script directory.

Examples:
  ./update_lomby_sim_packages.sh
  ./update_lomby_sim_packages.sh ~/autoware
  ./update_lomby_sim_packages.sh --dry-run ~/autoware

The workspace must already be built once. The script does not perform a full
Autoware build.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-deps)
      SKIP_DEPS=true
      shift
      ;;
    --rosdep-update)
      ROSDEP_UPDATE=true
      shift
      ;;
    -w|--workspace)
      [[ $# -ge 2 ]] || die "Missing value for $1"
      WORKSPACE="$2"
      shift 2
      ;;
    --workspace=*)
      WORKSPACE="${1#*=}"
      shift
      ;;
    -*)
      die "Unknown option: $1 (use --help for usage)"
      ;;
    *)
      WORKSPACE="$1"
      shift
      ;;
  esac
done

if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="$SCRIPT_DIR"
fi

[[ -d "$WORKSPACE" ]] || die "Workspace directory does not exist: $WORKSPACE"
WORKSPACE="$(cd -- "$WORKSPACE" && pwd)"
cd "$WORKSPACE"

info "Workspace: $WORKSPACE"

for cmd in git colcon rosdep python3; do
  command -v "$cmd" >/dev/null 2>&1 || die "Required command not found: $cmd"
done

python3 -c 'import yaml' >/dev/null 2>&1 ||
  die "PyYAML is required. Install it with: sudo apt install python3-yaml"

[[ -f "$WORKSPACE/autoware.repos" ]] ||
  die "autoware.repos not found in $WORKSPACE"

[[ -d "$WORKSPACE/src" ]] ||
  die "src/ not found in $WORKSPACE"

[[ -f "$WORKSPACE/install/setup.bash" ]] ||
  die "install/setup.bash not found. Build the full workspace once before running this script."

get_repo_version() {
  local key="$1"
  python3 - "$WORKSPACE/autoware.repos" "$key" <<'PY'
import sys
import yaml

with open(sys.argv[1]) as f:
    repositories = yaml.safe_load(f)["repositories"]

print(repositories[sys.argv[2]]["version"])
PY
}

check_repo_clean() {
  local key="$1"
  local repo_path="$WORKSPACE/src/$key"

  [[ -d "$repo_path/.git" ]] || die "Not a git repository: $repo_path"

  local dirty
  dirty="$(git -C "$repo_path" status --porcelain)"
  if [[ -n "$dirty" ]]; then
    printf '%s\n' "$dirty" >&2
    die "Local changes found in $repo_path. Commit or stash them first."
  fi
}

update_repo() {
  local key="$1"
  local version="${REPO_VERSIONS[$key]}"
  local repo_path="$WORKSPACE/src/$key"

  info "Updating src/$key (version: $version)"

  git -C "$repo_path" fetch origin

  if git -C "$repo_path" show-ref --verify --quiet "refs/remotes/origin/$version"; then
    if git -C "$repo_path" show-ref --verify --quiet "refs/heads/$version"; then
      git -C "$repo_path" switch "$version"
    else
      git -C "$repo_path" switch --track -c "$version" "origin/$version"
    fi

    local ahead
    ahead="$(git -C "$repo_path" rev-list --count "origin/$version..HEAD")"
    if [[ "$ahead" != "0" ]]; then
      die "$repo_path has $ahead local commit(s) not present in origin/$version. Aborting."
    fi

    info "Running: git -C $repo_path pull --ff-only --no-rebase origin $version"
    git -C "$repo_path" pull --ff-only --no-rebase origin "$version"

    local actual expected
    actual="$(git -C "$repo_path" rev-parse HEAD)"
    expected="$(git -C "$repo_path" rev-parse "origin/$version")"
    [[ "$actual" == "$expected" ]] ||
      die "Update failed for $key: expected $expected, got $actual"

    info "Updated $key to $actual"
  else
    info "Version '$version' is not an origin branch; checking out it directly"
    git -C "$repo_path" checkout --detach "$version"

    local actual expected
    actual="$(git -C "$repo_path" rev-parse HEAD)"
    expected="$(git -C "$repo_path" rev-parse --verify "${version}^{commit}" 2>/dev/null || true)"
    [[ -n "$expected" ]] ||
      die "Cannot resolve version '$version' for $key"
    [[ "$actual" == "$expected" ]] ||
      die "Checkout failed for $key: expected $expected, got $actual"

    info "Checked out $key at $actual"
  fi

  git -C "$repo_path" submodule update --init --recursive
}

declare -A REPO_VERSIONS=()

for key in "${REPO_KEYS[@]}"; do
  check_repo_clean "$key"
  REPO_VERSIONS["$key"]="$(get_repo_version "$key")"
done

if $DRY_RUN; then
  info "Dry run only; no changes will be made."
  for key in "${REPO_KEYS[@]}"; do
    info "Would pull src/$key on version '${REPO_VERSIONS[$key]}' with --ff-only"
  done
  info "Would rebuild: ${PACKAGES[*]}"
  exit 0
fi

for key in "${REPO_KEYS[@]}"; do
  update_repo "$key"
done

ROS_DISTRO="${ROS_DISTRO:-humble}"
ROS_SETUP="/opt/ros/${ROS_DISTRO}/setup.bash"
[[ -f "$ROS_SETUP" ]] || die "ROS setup not found: $ROS_SETUP"

info "Sourcing $ROS_SETUP"
set +u
# shellcheck disable=SC1090
source "$ROS_SETUP"
# shellcheck disable=SC1091
source "$WORKSPACE/install/setup.bash"
set -u

if $SKIP_DEPS; then
  info "Skipping dependency installation (--skip-deps)"
else
  if $ROSDEP_UPDATE; then
    info "Updating rosdep database"
    rosdep update
  fi

  REPO_PATHS=()
  for key in "${REPO_KEYS[@]}"; do
    REPO_PATHS+=("$WORKSPACE/src/$key")
  done

  info "Installing missing dependencies"
  rosdep install -y -r \
    --from-paths "${REPO_PATHS[@]}" \
    --ignore-src --rosdistro "$ROS_DISTRO"
fi

info "Building selected packages: ${PACKAGES[*]}"
colcon build --symlink-install \
  --packages-select "${PACKAGES[@]}" \
  --cmake-args -DCMAKE_BUILD_TYPE=Release

info "Sourcing the updated workspace"
set +u
# shellcheck disable=SC1091
source "$WORKSPACE/install/setup.bash"
set -u

for pkg in "${PACKAGES[@]}"; do
  if prefix="$(ros2 pkg prefix "$pkg" 2>/dev/null)"; then
    info "Installed $pkg -> $prefix"
  else
    warn "Package not found after build: $pkg"
  fi
done

info "Done."
info "To use the workspace in a new shell: source $WORKSPACE/install/setup.bash"

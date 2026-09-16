# Autoware - the world's leading open-source software project for autonomous driving

![Autoware_RViz](https://user-images.githubusercontent.com/63835446/158918717-58d6deaf-93fb-47f9-891d-e242b02cba7b.png)
[![Discord](https://img.shields.io/discord/953808765935816715?label=Autoware%20Discord&style=for-the-badge)](https://discord.gg/Q94UsPvReQ)

Autoware is an open-source software stack for self-driving vehicles, built on the [Robot Operating System (ROS)](https://www.ros.org/). It includes all of the necessary functions to drive an autonomous vehicles from localization and object detection to route planning and control, and was created with the aim of enabling as many individuals and organizations as possible to contribute to open innovations in autonomous driving technology.

![Autoware architecture](https://static.wixstatic.com/media/984e93_552e338be28543c7949717053cc3f11f~mv2.png/v1/crop/x_0,y_1,w_1500,h_879/fill/w_863,h_506,al_c,usm_0.66_1.00_0.01,enc_auto/Autoware-GFX_edited.png)

## Lomby: the Unity simulation branch

`feature/LMA5-Nav2-sim` runs the Unity simulator (LOMBYSIM) against the LMA5-Nav2 production
stack. It is that production branch plus the simulator's sensor kit, vehicle interface, launch
files and rviz configuration. Nav2 plans and controls; Autoware supplies perception and
localization.

### What `autoware.repos` changes

Three repositories are pinned to simulation branches rather than the production ones:

| Repository | Production | Simulation |
| --- | --- | --- |
| `universe/autoware.universe` | `feature/LMA5-michibiki` | `feature/LMA5-michibiki-sim` |
| `lomby_autoware/launcher/autoware_launch_lomby` | `feature/LMA5-Nav2` | `feature/LMA5-Nav2-sim` |
| `param/lomby_autoware_individual_params` | `LMA1` | `sim-mid360` |

and four are added for the simulated robot:

- `lomby_autoware/sensor_kit/lomby_sim_sensor_kit_launch` @ `mid-360`
- `lomby_autoware/vehicle/lomby_sim_launch` @ `main`
- `sensor_component/external/mid360_description` @ `main`
- `lomby_autoware/universe/external/moving_object_filter` @ `main`

Nothing else differs from production, so `vcs import --recursive src < autoware.repos` on this
branch gives the production workspace with the simulator dropped in.

### Building and running

Everything below runs inside the `ros-humble` distrobox.

```bash
colcon build --symlink-install --packages-skip sllidar_ros2 pacmod_interface
```

Start LOMBYSIM first, then, from a fresh shell:

```bash
source install/setup.bash
source ~/ws_nav2/install/nav2_msgs/share/nav2_msgs/package.bash   # nav2_msgs only, see below
ros2 launch autoware_launch_lomby e2e_simulator.launch.xml \
  vehicle_model:=lomby_sim sensor_model:=lomby_sim_sensor_kit \
  map_path:=$HOME/autoware_map/nishishinjuku_autoware_map/ \
  launch_vehicle_interface:=true use_lidar_preprocessing:=false
```

Source only the `nav2_msgs` package out of `ws_nav2`, never the whole workspace. Autoware needs
`nav2_msgs` from there because Humble's binary package has no `DockRobot`, but
`nav2_system_tests` installs a `libsmoother.so` that shadows Autoware's velocity smoother, and
the planning and control containers then exit with code 127.

### The simulator has no GNSS/INS

`use_autoware_pose_covariance_modifier` is **false** on this branch and has to stay that way.
Production enables `autoware_pose_covariance_modifier` for the Michibiki/QZSS receiver; the node
chooses between the GNSS and NDT poses by reading the GNSS standard deviations. LOMBYSIM has no
such receiver and publishes `/sensing/gnss/pose_with_covariance` with an all-zero covariance and
an all-zero orientation quaternion. Zero standard deviation reads as a perfect fix, so the node
selects GNSS only, discards NDT entirely, and hands `ekf_localizer` a quaternion of length zero.
Normalising that divides by zero, so `map -> base_link` goes out as `(x y nan)` with a NaN
quaternion. Every tf2 listener rejects it, which costs thousands of `TF_NAN_INPUT` errors a
second, localization, and the occupancy grid along with it.

## Documentation

To learn more about using or developing Autoware, refer to the [Autoware documentation site](https://autowarefoundation.github.io/autoware-documentation/main/). You can find the source for the documentation in [autowarefoundation/autoware-documentation](https://github.com/autowarefoundation/autoware-documentation).

## Repository overview

- [autowarefoundation/autoware](https://github.com/autowarefoundation/autoware)
  - Meta-repository containing `.repos` files to construct an Autoware workspace.
  - It is anticipated that this repository will be frequently forked by users, and so it contains minimal information to avoid unnecessary differences.
- [autowarefoundation/autoware_common](https://github.com/autowarefoundation/autoware_common)
  - Library/utility type repository containing commonly referenced ROS packages.
  - These packages were moved to a separate repository in order to reduce CI execution time
- [autowarefoundation/autoware.core](https://github.com/autowarefoundation/autoware.core)
  - Main repository for high-quality, stable ROS packages for Autonomous Driving.
  - Based on [Autoware.Auto](https://gitlab.com/autowarefoundation/autoware.auto/AutowareAuto) and [Autoware.Universe](https://github.com/autowarefoundation/autoware.universe).
- [autowarefoundation/autoware.universe](https://github.com/autowarefoundation/autoware.universe)
  - Repository for experimental, cutting-edge ROS packages for Autonomous Driving.
  - Autoware Universe was created to make it easier for researchers and developers to extend the functionality of Autoware Core
- [autowarefoundation/autoware_launch](https://github.com/autowarefoundation/autoware_launch)
  - Launch configuration repository containing node configurations and their parameters.
- [autowarefoundation/autoware-github-actions](https://github.com/autowarefoundation/autoware-github-actions)
  - Contains [reusable GitHub Actions workflows](https://docs.github.com/ja/actions/learn-github-actions/reusing-workflows) used by multiple repositories for CI.
  - Utilizes the [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) concept.
- [autowarefoundation/autoware-documentation](https://github.com/autowarefoundation/autoware-documentation)
  - Documentation repository for Autoware users and developers.
  - Since Autoware Core/Universe has multiple repositories, a central documentation repository is important to make information accessible from a single place.

## Using Autoware.AI

If you wish to use Autoware.AI, the previous version of Autoware based on ROS 1, switch to [autoware-ai](https://github.com/autowarefoundation/autoware_ai) repository. However, be aware that Autoware.AI has reached the end-of-life as of 2022, and we strongly recommend transitioning to Autoware Core/Universe for future use.

## Contributing

- [There is no formal process to become a contributor](https://github.com/autowarefoundation/autoware-projects/wiki#contributors) - you can comment on any [existing issues](https://github.com/autowarefoundation/autoware.universe/issues) or make a pull request on any Autoware repository!
  - Make sure to follow the [Contribution Guidelines](https://autowarefoundation.github.io/autoware-documentation/main/contributing/).
  - Take a look at Autoware's [various working groups](https://github.com/autowarefoundation/autoware-projects/wiki#working-group-list) to gain an understanding of any work in progress and to see how projects are managed.
- If you have any technical questions, you can start a discussion in the [Q&A category](https://github.com/autowarefoundation/autoware/discussions/categories/q-a) to request help and confirm if a potential issue is a bug or not.

## Useful resources

- [Autoware Foundation homepage](https://www.autoware.org/)
- [Support guidelines](https://autowarefoundation.github.io/autoware-documentation/main/support/support-guidelines/)

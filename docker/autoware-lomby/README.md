# Docker images for Lomby Autoware

## Prerequisites

- [Docker](https://docs.docker.com/engine/install/ubuntu/)

The [setup script](../setup-dev-env.sh) will install these dependencies.

## Usage

### Development image
Build the docker image with below command:

```
docker build --platform linux/amd64 -t autoware-dev:v2.0 .
```
Push the image to ECR registry:
```
docker push 103382653610.dkr.ecr.ap-northeast-1.amazonaws.com/autoware-dev:v0.0
```
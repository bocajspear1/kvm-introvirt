#!/bin/bash
DISTRO=$(echo "$1" | cut -d'/' -f 1)
echo "DISTRO: ${DISTRO}"
DISTRO_RELEASE=$(echo "$1" | cut -d'/' -f 2)
echo "DISTRO_RELEASE: ${DISTRO_RELEASE}"

if [ "${DISTRO}" = "ubuntu" ]; then
    if [ "${DISTRO_RELEASE}" = "focal" ]; then
        DOCKER_BUILDKIT=1 docker build --progress=plain --build-arg UBUNTU_KERNEL_VERSION=$1 -f docker/Dockerfile-ubuntu-focal --target artifact --output type=local,dest=. .
    elif [ "${DISTRO_RELEASE}" = "bionic" ]; then
        DOCKER_BUILDKIT=1 docker build --progress=plain --build-arg UBUNTU_KERNEL_VERSION=$1 -f docker/Dockerfile-ubuntu-bionic --target artifact --output type=local,dest=. .
    fi
elif [ "${DISTRO}" = "rocky" ]; then
    if [ "${DISTRO_RELEASE}" = "8" ]; then
        DOCKER_BUILDKIT=1 docker build --progress=plain --build-arg ROCKY_KERNEL_VERSION=$1 -f docker/Dockerfile-rocky-8 --target artifact --output type=local,dest=. .
    fi
fi
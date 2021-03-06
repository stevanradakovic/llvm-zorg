#!/bin/bash
#===-- build_run.sh ------------------------------------------------------===//
# Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
#
#===----------------------------------------------------------------------===//
# This script will deploy a docker image to the registry.
# Arguments:
#     <path to Dockerfile>
#     <path containing secrets>
#     optional: <command to be executed in the container>
#===----------------------------------------------------------------------===//

set -eu

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
IMAGE_NAME="${1%/}"
SECRET_STORAGE="$2"
CMD=
if [ "$#" -eq 3 ];
then
    CMD="$3"
fi

cd "${DIR}/${IMAGE_NAME}"

# Mount a volume "workertest" to persit across test runs.
# Use this to keep e.g.  a git checkout or partial build across runs
if [[ $(docker volume ls | grep workertest | wc -l) == 0 ]] ; then
    docker volume create workertest
fi

# Volume to presist the build cache e.g. ccache or sccache.
# This will speed up local testing.
if [[ $(docker volume ls | grep workercache | wc -l) == 0 ]] ; then
    docker volume create workercache
fi

# Define arguments for mounting the volumes
# These differ on Windows and Linux
VOLUMES="-v ${SECRET_STORAGE}:/vol/secrets -v workertest:/vol/test -v workercache:/vol/ccache"
if [ -n "${OS+x}" ] && [[  "${OS}" == "Windows_NT" ]] ; then
    VOLUMES="-v ${SECRET_STORAGE}:c:\\volumes\\secrets -v workertest:c:\volumes\\test -v workercache:c:\sccache"
fi

# Set container arguments, if they are set in the environment:
ARGS=""
if [ -n "${BUILDBOT_PORT+x}" ] ; then
    ARGS+=" -e BUILDBOT_PORT=${BUILDBOT_PORT}"
fi

docker build -t "${IMAGE_NAME}:latest" .
docker run -it ${VOLUMES} ${ARGS} "${IMAGE_NAME}:latest" ${CMD}

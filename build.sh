#!/bin/bash

# Gather parameters
if [ $# -eq 0 ];then
    perro "No argument supplied"
    exit 1
fi
build_tag=$1

# Verify provided parameters
echo TAG: "${build_tag:?}"

# Exit on error
set -e

docker build --no-cache -t $build_tag .

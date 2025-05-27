#!/bin/bash

# starts the local bitcoin node from docker-compose file

KNOTS_VERSION="$(cat ./KNOTS_VERSION)"
IMAGE_NAME="bitcoind-k"
alpine_mode=false

usage() {
  echo
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo " -h, --help      Display this help message"
  echo " -a, --alpine    Build the image based on Alpine"
  echo " -v, --version   Specify the version of Bitcoin Knots to be built"
  echo
}

handle_options() {
  while getopts 'hav:' flag; do
    case $1 in
      -h | --help) usage; exit 0 ;;
      -a | --alpine) alpine_mode=true ;;
      -v | --version) KNOTS_VERSION="${OPTARG}" ;;
      *)
        echo "Invalid option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

handle_options "$@"

if [ ! -d "$KNOTS_VERSION" ] ; then
    echo "Dockerfile for $KNOTS_VERSION does not exist"
    exit 1
fi

DOCKERFILE_PATH="$KNOTS_VERSION/Dockerfile"

if [ "$alpine_mode" = true ]; then
 echo "Alpine mode enabled."
 DOCKERFILE_PATH="$KNOTS_VERSION/alpine/Dockerfile"
fi

echo "Building image $IMAGE_NAME.."

docker build -t "$IMAGE_NAME" -f "$DOCKERFILE_PATH" .

RESULT=$?
if [ $RESULT -eq 0 ]; then
  echo "Successfully built $IMAGE_NAME."
else
  echo "Issue building $IMAGE_NAME."
fi


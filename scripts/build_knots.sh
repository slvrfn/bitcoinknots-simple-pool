#!/bin/bash

# starts the local bitcoin node from docker-compose file

KNOTS_VERSION="$(cat ./LATEST_KNOTS)"
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
  # adapted from https://stackoverflow.com/a/28466267

  die() { echo "$*" >&2; usage; exit 2; }  # complain to STDERR and exit with error
  needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

  while getopts hav:-: OPT; do  # allow -a, -b with arg, -c, and -- "with arg"
    # support long options: https://stackoverflow.com/a/28466267/519360
    if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
      OPT="${OPTARG%%=*}"       # extract long option name
      OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
      OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    case "$OPT" in
      h | help )     usage; exit 0 ;;
      a | alpine )   alpine_mode=true ;;
      v | version )  needs_arg; KNOTS_VERSION="$OPTARG" ;;
      \? )           usage; exit 2 ;;  # bad short option (error reported via getopts)
      * )            die "Illegal option --$OPT" ;;            # bad long option
    esac
  done
}

handle_options "$@"

DOCKERFILE_PATH="bitcoin-knots/Dockerfile"

if [ "$alpine_mode" = true ]; then
 echo "Alpine mode enabled."
 DOCKERFILE_PATH="bitcoin-knots/alpine/Dockerfile"
fi

echo "Building $KNOTS_VERSION into image $IMAGE_NAME.."

docker build -t "$IMAGE_NAME" --build-arg BITCOIN_VERSION="$KNOTS_VERSION" -f "$DOCKERFILE_PATH" .

RESULT=$?
if [ $RESULT -eq 0 ]; then
  echo "Successfully built $IMAGE_NAME."
else
  echo "Issue building $IMAGE_NAME."
fi


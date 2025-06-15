#!/bin/bash

# starts the local bitcoin node from docker-compose file

ACTION=
HTTPS=false
NODE=false
POOL=false
DAEMON=false
SERVICE=
PROFILES=()

usage() {
  echo
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo " -h, --help     Display this help message"
  echo " -n, --node     Specify the Bitcoin Nodes service"
  echo " -p, --pool     Specify the Bitcoin Node & Mining pool services"
  echo " -d, --daemon   Start the service in DAEMON mode (only applies to start action)"
  echo " -s, --https    Run the POOL service over https (only affects the POOL service)"
  echo " -a, --action   Action to be performed (required)"
  echo "       start    Start the specified service"
  echo "       stop     Stop the specified service"
  echo "       nlog     Display the logs for the Node service"
  echo "       log      Display the logs for all services"
  echo
  echo "You must chose one of the 'n'/'p' options for the start/stop action. You can make"
  echo "the Pool ui/api available over HTTPS by specifying the 's' option."
  echo
}

handle_options() {
  # adapted from https://stackoverflow.com/a/28466267

  die() { echo "$*" >&2; usage; exit 2; }  # complain to STDERR and exit with error
  needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

  while getopts hsnpda:-: OPT; do
    # support long options: https://stackoverflow.com/a/28466267/519360
    if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
      OPT="${OPTARG%%=*}"       # extract long option name
      OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
      OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
    fi
    case "$OPT" in
      h | help)    usage; exit 0 ;;
      s | https)   HTTPS=true ;;
      n | node)    NODE=true ;;
      p | pool)    POOL=true ;;
      d | daemon)  DAEMON=true ;;
      a | action)  needs_arg; ACTION="$OPTARG" ;;
      \? )         usage; exit 2 ;;  # bad short option (error reported via getopts)
      * )          die "Illegal option --$OPT" ;;  # bad long option
    esac
  done
}

check_service() {
  if [ "$NODE" = true ] ; then
    echo
    echo "Node service specified."
    SERVICE="NODE"
    PROFILES=(--profile node)
  fi

  if [ "$POOL" = true ] ; then
    echo
    echo "Pool service specified."
    SERVICE="POOL"
    PROFILES=(--profile node --profile pool)
  fi

  # check if array empty
  if (( ${#PROFILES[@]} == 0 )); then
    echo
    echo "You must specify a service." >&2
    echo "Usage: $0 -[n|p]" >&2
    usage
    exit 1
  fi
}

handle_options "$@"

# Check if an action was provided
if [ -z "${ACTION}" ]; then
  echo
  echo "You must provide an action." >&2
  echo "Usage: $0 -a [start|stop|nlog|log]" >&2
  usage
  exit 1
fi

docker_cmd=(docker compose)

echo "Action is '${ACTION}'."

# Perform a different action based on the value of the ACTION variable
case "${ACTION}" in
  start)
    check_service
    echo "Starting $SERVICE service..."

    # Specify service to be started by using a docker compose profile
    docker_cmd+=("${PROFILES[@]}")

    # handle HTTPS option for POOL service
    if [ "$HTTPS" = true ] && [ "$POOL" = true ] ;
      then
        echo "Running POOL service over HTTPS."
        docker_cmd+=(-f "compose_https.yml")
      else
        docker_cmd+=(-f "compose_http.yml")
    fi

    docker_cmd+=(up)

    # handle DAEMON option
    if [ "$DAEMON" = true ] ; then
      echo "Starting $SERVICE in DAEMON mode."
      docker_cmd+=(-d)
    fi
    ;;
  stop)
    check_service
    echo "Stopping $SERVICE service..."
    docker_cmd+=("${PROFILES[@]}")
    # handle HTTPS option for POOL service
    if [ "$HTTPS" = true ] && [ "$POOL" = true ] ;
      then
        docker_cmd+=(-f "compose_https.yml")
      else
        docker_cmd+=(-f "compose_http.yml")
    fi
    docker_cmd+=(down)
    ;;
  nlog)
    echo "Tailing bitcoin node logs"
    docker_cmd=(docker logs bitcoindk --follow)
    ;;
  log)
    echo "Tailing all service logs"
    check_service
    docker_cmd=(docker compose)

    if [ "$HTTPS" = true ] ;
      then
        docker_cmd+=(-f "compose_https.yml")
      else
        docker_cmd+=(-f "compose_http.yml")
    fi

    docker_cmd+=("${PROFILES[@]}" logs --follow)
    ;;
  *)
    # Handle any other value
    echo "Error: Unknown action '${ACTION}'."
    usage
    exit 1
    ;;
esac

echo "Executing: ${docker_cmd[*]}"

"${docker_cmd[@]}"
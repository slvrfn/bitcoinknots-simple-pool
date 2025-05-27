#!/bin/bash

setup_all=false
setup_rpc=false
setup_domain=false

RPC_USER=
RPC_PASSWORD=
DOMAIN=
EMAIL=


usage() {
  echo
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo " -h, --help     Display this help message"
  echo " -r, --rpc      Assign Both RPC Auth credentials"
  echo " -d, --domain   Assign Public-Pool Domain/Email"
  echo " -a, --all      Assign Both RPC Auth credentials and the Public-Pool Domain/Email"
  echo
}

handle_options() {
  while getopts 'hard' flag; do
    case $1 in
      -h | --help) usage; exit 0 ;;
      -a | --all) setup_all=true ;;
      -r | --rpc) setup_rpc=true ;;
      -d | --domain) setup_domain=true ;;
      *)
        echo "Invalid option: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

# Function to generate random credential strings
generate_random_string() {
    openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w 21 | head -n 1
}

update_rpc() {
  echo "Updating RPC credentials"
  # Generate secure RPC credentials
  RPC_USER=$(generate_random_string)
  RPC_PASSWORD=$(generate_random_string)

  # Update configuration files
  sed -i '' "s/\(rpcuser=\).*/\1\"$RPC_USER\"/" bitcoin.conf
  sed -i '' "s/\(rpcpassword=\).*/\1\"$RPC_PASSWORD\"/" bitcoin.conf

  sed -i '' "s/\(BITCOIN_RPC_USER=\).*/\1\"$RPC_USER\"/" pool.env
  sed -i '' "s/\(BITCOIN_RPC_PASSWORD=\).*/\1\"$RPC_PASSWORD\"/" pool.env
}

update_domain() {
    # Prompt for domain
    read -rp "Enter the domain for your Bitcoin node (or press Enter for 'localhost'): " DOMAIN
    DOMAIN=${DOMAIN:-localhost}
    read -rp "Enter the email to be associated with the SSL certificate (or press Enter for 'example@example.com'): " EMAIL
    EMAIL=${EMAIL:-example@example.com}

    # Update compose fields
    sed -i '' "s/\(- \"--certificatesresolvers\.selfhostedservices\.acme\.email=\).*/\1$EMAIL\"/" compose.yml

    sed -i '' "s/\(- \"traefik\.http\.routers\.public-pool-api\.rule=\).*/\1Host(\`$DOMAIN\`) \&\& PathPrefix(`\/api`)\"/" compose.yml
    sed -i '' "s/\(DOMAIN=\).*/\1\"$DOMAIN\"/" compose.yml
    sed -i '' "s/\(- \"traefik\.http\.routers\.public-pool-ui\.rule=\).*/\1Host(\`$DOMAIN\`)\"/" compose.yml
}

handle_options "$@"

UPDATE_MADE=false

if [ "$setup_rpc" = true ] || [ "$setup_all" = true ] ; then
  update_rpc
  UPDATE_MADE=true
fi

if [ "$setup_domain" = true ] || [ "$setup_all" = true ] ; then
  update_domain
  UPDATE_MADE=true
fi

if [ "$UPDATE_MADE" = true ]; then

  if [ "$setup_rpc" = true ] || [ "$setup_all" = true ] ; then
    echo ""
    echo "WARNING: The following credentials will only be displayed ONCE."
    echo "Please save them in a secure location immediately!!!!!!!!"
    echo ""
    echo "Generated RPC credentials:"
    echo "RPC User: $RPC_USER"
    echo "RPC Password: $RPC_PASSWORD"
    echo ""
    echo "These credentials have been automatically added to your bitcoin.conf and pool.env."
    echo "Make sure to keep these files secure and do not share them."
    echo ""
  fi

  if [ "$setup_domain" = true ] || [ "$setup_all" = true ] ; then
    echo ""
    echo "These credentials have been automatically added to the compose.yml"
    echo ""
    echo "Updated fields:"
    echo ""
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo ""
  fi

else
  # Commands to execute when setup_rpc is not true
  echo
  echo "No parameters specified."
  usage
fi

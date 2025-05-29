# bitcoinknots-simple-pool

This is a repository to simplify solo-mining via Docker Compose.

This is made possible by spinning up a new Bitcoin Knots Public-Pool instance.

For background information to setup a public-pool instance using this repo, please read the full guide on [Sethforprivacy](https://github.com/sethforprivacy)'s blog:

https://sethforprivacy.com/guides/run-your-own-bitcoin-pool

This repo contains:
- Dockerfiles which can be used to build a Bitcoin Knots image
- Docker-Compose configuration which defines a service to host a local Bitcoin node & Public-Pool instance

## Looking for Bitcoin Core images?

The `bitcoind-k` (Bitcoin Knots) image here is drop-in replacements for the `bitcoin/bitcoin` (Bitcoin Core) images. If you're looking for actual Bitcoin Core images, go to [willcl-ark/bitcoin-core-docker](https://github.com/willcl-ark/bitcoin-core-docker).

## About the images

> [!IMPORTANT]
> These Dockerfiles create **unofficial** Bitcoin Knots images, not endorsed or associated with the Bitcoin Knots project on GitHub: github.com/bitcoinknots/bitcoin

- The Bitcoin Knots images specified here `bitcoind-k` are not hosted anywhere, and are left to you to build as shown in the [build section](#how-to-build-the-bitcoin-knots-images). _"Don't trust, verify"_
- The Debian-based (non-alpine) images use pre-built binaries pulled from [bitcoinknots.org](bitcoinknots.org). These binaries are built using the Bitcoin Knots [reproducible build](https://github.com/bitcoinknots/bitcoin/blob/master/contrib/guix/README.md) system, and signatures attesting to them can be found in the [guix.sigs](https://github.com/bitcoinknots/guix.sigs) repo. Signatures are checked in the build process for these docker images using the [verify_binaries.py](https://github.com/bitcoinknots/bitcoin/tree/master/contrib/verify-binaries) script from the bitcoinknots/bitcoin git repository.
- The alpine images are built from source.

> [!IMPORTANT]
> The Alpine Linux distribution, whilst being a resource efficient Linux distribution with security in mind, is not officially supported by the Bitcoin Knots team nor the Bitcoin Core team — use at your own risk.

## Usage

### How to build the Bitcoin Knots images

A script is provided here to manually build the Bitcoin knots images at `scripts/build_knots.sh`. This script simplifies the process of building the images locally, and provides an option to build the Debian-based or Alpine-based images:

```sh
Usage: ./scripts/build_knots.sh [OPTIONS]
Options:
 -h, --help      Display this help message
 -a, --alpine    Build the image based on Alpine
 -v, --version   Specify the version of Bitcoin Knots to be built
```
> [!IMPORTANT]
> By default, the version of Bitcoin Knots specified in `LATEST_KNOTS` will be built. This can be changed by specifying an alternate version using the `-v` flag as shown above. Other versions that have been tested with this Docker build process are in `KNOTS_VERSIONS`.

### How to update the RPC Auth details and Public-Pool Domain

By default, this repo defines:
- the RPC credentials as `rpcuser=bitcoin` and `rpcpassword=bitcoin`
- the Public-Pool domain as `localhost` and the LetsEncrypt SSL certificate email as `example@example.com`.

A script is provided here at `scripts/setup.sh` to simplify the process of updating the Bitcoin Node's RPC authentication credentials and also the Domain/Email used by Public-Pool.

```sh
Usage: ./scripts/setup.sh [OPTIONS]
Options:
 -h, --help     Display this help message
 -r, --rpc      Assign Both RPC Auth credentials
 -d, --domain   Assign Public-Pool Domain/Email
 -a, --all      Assign Both RPC Auth credentials and the Public-Pool Domain/Email
```
When running the script, you must pass in one of the options `-r` `-d` (or `-a`), for any modifications to be made.

The Public-Pool service/UI can be hosted locally (localhost is default), or hosted on a publicly accessible URL such as https://web.public-pool.io/#/.

### How to start the local node/mining-pool service
Two scripts are provided here to simplify the process of starting/stopping the local Bitcoin node and Public-Pool service. They are simple wrappers of `docker-compose`, and are expected to be run from the repo's root directory.

- `./scripts/start_node.sh`
- `./scripts/stop_node.sh`

### How to use the Bitcoin Knots images

These images contain the main binaries from the Bitcoin Knots project - `bitcoind`, `bitcoin-cli` and `bitcoin-tx`. The images behave like binaries, so you can pass arguments to the image, and they will be forwarded to the `bitcoind` binary (by default, other binaries on demand):

```sh
❯ docker run --rm -it bitcoind-k \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcuser=bitcoin \
  -rpcpassword=bitcoin
```

_Note: [learn more](#generate-secure-rpc-credentials) about how you can automatically generate secure values for `-rpcuser` & `-rpcpassword`._

By default, `bitcoind` will run as user `bitcoin` in the group `bitcoin` for security reasons and its default data directory is set to `/bitcoin/.bitcoin`. If you'd like to customize where `bitcoin` stores its data, you must use the `BITCOIN_DATA` environment variable. The directory will be automatically created with the correct permissions for the `bitcoin` user and `bitcoind` automatically configured to use it.

```sh
❯ docker run --env BITCOIN_DATA=/var/lib/bitcoinknots --rm -it bitcoind-k \
  -printtoconsole \
  -regtest=1
```

You can also mount a directory in a volume under `/bitcoin/.bitcoin` in case you want to access it on the host:

```sh
❯ docker run -v ${PWD}/data:/bitcoin/.bitcoin -it --rm bitcoind-k \
  -printtoconsole \
  -regtest=1
```

You can optionally create a custom service using `docker-compose`:

```yml
bitcoin-server:
  image: bitcoind-k
  command:
    -printtoconsole
    -regtest=1
```

### Using a custom user id (UID) and group id (GID)

By default, images are created with a `bitcoin` user/group using a static UID/GID (`101:101` on Debian and `100:101` on Alpine). You may customize the user and group ids using the build arguments `UID` (`--build-arg UID=<uid>`) and `GID` (`--build-arg GID=<gid>`).

If you'd like to use the pre-built images, you can also customize the UID/GID on runtime via environment variables `$UID` and `$GID`:

```sh
❯ docker run -e UID=10000 -e GID=10000 -it --rm bitcoind-k \
  -printtoconsole \
  -regtest=1
```

This will recursively change the ownership of the `bitcoin` home directory and `$BITCOIN_DATA` to UID/GID `10000:10000`.

### Using RPC to interact with the daemon

There are two communications methods to interact with a running Bitcoin Knots daemon.

The first one is using a cookie-based local authentication. It doesn't require any special authentication information as running a process locally under the same user that was used to launch the Bitcoin Knots daemon allows it to read the cookie file previously generated by the daemon for clients. The downside of this method is that it requires local machine access.

The second option is making a remote procedure call using a username and password combination. This has the advantage of not requiring local machine access. You can automatically generate secure values for the RPC credentials: [learn more](#generate-secure-rpc-credentials).

#### Using cookie-based local authentication

Start by launch the Bitcoin Knots daemon:

```sh
❯ docker run --rm --name bitcoin-server -it bitcoind-k \
  -printtoconsole \
  -regtest=1
```

Then, inside the running same `bitcoin-server` container, locally execute the query to the daemon using `bitcoin-cli`:

```sh
❯ docker exec --user bitcoin bitcoin-server bitcoin-cli -regtest getmininginfo

{
  "blocks": 0,
  "currentblocksize": 0,
  "currentblockweight": 0,
  "currentblocktx": 0,
  "difficulty": 4.656542373906925e-10,
  "errors": "",
  "networkhashps": 0,
  "pooledtx": 0,
  "chain": "regtest"
}
```

`bitcoin-cli` reads the authentication credentials automatically from the [data directory](https://github.com/bitcoinknots/bitcoin/blob/master/doc/files.md#data-directory-layout), on mainnet this means from `$DATA_DIR/.cookie`.

#### Generate secure RPC credentials

Before setting up remote authentication, you can securely generate the `rpcuser` & `rpcpassword` credentials for the Bitcoind Knots daemon (and Public-Pool service). You can either do this yourself by updating the fields in `bitcoin.conf` & `pool.env` or use the `scripts/setup.sh` script (with the `-r` flag) to update these lines for you, printing the updated details to the console.

Example:

```sh
❯ ./scripts/setup.sh -r
Updating RPC credentials

WARNING: The following credentials will only be displayed ONCE.
Please save them in a secure location immediately!!!!!!!!

Generated RPC credentials:
RPC User: ZaFODLzqlXO3gldj3Diby
RPC Password: pvYILLeAhpqSVZsYiqLGk

These credentials have been automatically added to your bitcoin.conf and pool.env.
Make sure to keep these files secure and do not share them.
```

Note that for each run, the output will be always different as the values are randomly generated.

> [!IMPORTANT]
> These values should be protected. If an unauthorized party gets access to these credentials, they will be able to access your Bitcoin Node over RPC.

#### Using rpcauth for remote authentication

An alternate (more recent) mode of remote authentication, is using `rpcauth`. If you want to use this method, you will need to generate the `rpcauth` line that will hold the credentials for the Bitcoind Knots daemon. 

You can do this yourself by:
- constructing the line with the format `<user>:<salt>$<hash>`
- using the included script `scripts/rpcauth/rpcauth.py`
- using the official [rpcauth.py](https://github.com/bitcoinknots/bitcoin/blob/master/share/rpcauth/rpcauth.py)

The latter two are scripts to generate this line for you, including a random password that is printed to the console

_Note: This is a Python 3 script. use `python3 scripts/rpcauth/rpcauth.py <username>` when executing on macOS._

Example:

```sh
❯ python scripts/rpcauth/rpcauth.py <username>

String to be appended to bitcoin.conf:
rpcauth=foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc
Your password:
qDDZdeQ5vw9XXFeVnXT4PZ--tGN2xNjjR4nrtyszZx0=
```

Note that for each run, even if the username remains the same, the output will be always different as a new salt and password are generated.

> [!IMPORTANT]
> As of the time of writing, this auth method is not supported by Public-Pool mining pool included in the provided docker-compose configuration.

Now that you have your credentials, you need to start the Bitcoin Knots daemon with the `-rpcauth` option. Alternatively, you could append the line to a `bitcoin.conf` file and mount it on the container.

Let's opt for the Docker way:

```sh
❯ docker run --rm --name bitcoin-server -it bitcoind-k \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcauth='foo:7d9ba5ae63c3d4dc30583ff4fe65a67e$9e3634e81c11659e3de036d0bf88f89cd169c1039e6e09607562d54765c649cc'
```

Two important notes:

1. Some shells require escaping the rpcauth line (e.g. zsh).
2. It is now perfectly fine to pass the rpcauth line as a command line argument. Unlike `-rpcpassword`, the content is hashed so even if the arguments would be exposed, they would not allow the attacker to get the actual password.

To avoid any confusion about whether or not a remote call is being made, let's spin up another container to execute `bitcoin-cli` and connect it via the Docker network using the password generated above:

```sh
❯ docker run -it --link bitcoin-server --rm bitcoind-k \
  bitcoin-cli \
  -rpcconnect=bitcoin-server \
  -regtest \
  -rpcuser=foo\
  -stdinrpcpass \
  getbalance
```

Enter the password `qDDZdeQ5vw9XXFeVnXT4PZ--tGN2xNjjR4nrtyszZx0=` and hit enter:

```
0.00000000
```

### Exposing Ports

Depending on the network (mode) the Bitcoin Knots daemon is running as well as the chosen runtime flags, several default ports may be available for mapping.

Ports can be exposed by mapping all of the available ones (using `-P` and based on what `EXPOSE` documents) or individually by adding `-p`. This mode allows assigning a dynamic port on the host (`-p <port>`) or assigning a fixed port `-p <hostPort>:<containerPort>`.

Example for running a node in `regtest` mode mapping JSON-RPC/REST (18443) and P2P (18444) ports:

```sh
docker run --rm -it \
  -p 18443:18443 \
  -p 18444:18444 \
  bitcoind-k \
  -printtoconsole \
  -regtest=1 \
  -rpcallowip=172.17.0.0/16 \
  -rpcbind=0.0.0.0 \
  -rpcuser=bitcoin \
  -rpcpassword=bitcoin
```

To test that mapping worked, you can send a JSON-RPC curl request to the host port:

```
curl --data-binary '{"jsonrpc":"1.0","id":"1","method":"getnetworkinfo","params":[]}' http://foo:qDDZdeQ5vw9XXFeVnXT4PZ--tGN2xNjjR4nrtyszZx0=@127.0.0.1:18443/
```

#### Mainnet

- JSON-RPC/REST: 8332
- P2P: 8333

#### Testnet

- JSON-RPC: 18332
- P2P: 18333

#### Regtest

- JSON-RPC/REST: 18443
- P2P: 18444

#### Signet

- JSON-RPC/REST: 38332
- P2P: 38333

## License

[License information](https://github.com/slvrfn/bitcoinknots-simple-pool/blob/master/LICENSE) For the code in this repo.

- [Bitcoin Knots](https://github.com/bitcoinknots/bitcoin/blob/master/COPYING) for the Bitcoin Knots software contained in this repo.
- [Public-Pool](https://github.com/benjamin-wilson/public-pool/blob/master/LICENSE.txt) for the Public-Pool software contained in this repo.
- [traefik](https://github.com/traefik/traefik-library-image/blob/master/LICENSE) for the traefik software contained in this repo.
- [watchtower](https://github.com/containrrr/watchtower/blob/main/LICENSE.md) for the watchtower software contained in this repo.

### Credits
This repository is based on the work of:
- [Nicolas Dorier](https://github.com/NicolasDorier)
- [Benjamin Wilson](https://github.com/benjamin-wilson/)
- [Sethforprivacy](https://github.com/sethforprivacy)
- [Kyle Manna](https://github.com/kylemanna)
- [TheBitcoinProf](https://github.com/TheBitcoinProf/)
- [Yasu Takumi](https://github.com/yasutakumi)
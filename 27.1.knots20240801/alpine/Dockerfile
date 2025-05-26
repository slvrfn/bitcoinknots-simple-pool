# common back image (allows ENV variable sharing)
FROM alpine:3.21 AS base

ENV BITCOIN_VERSION=27.1.knots20240801
ENV BITCOIN_PREFIX=/opt/bitcoin-${BITCOIN_VERSION}

# Build stage for Bitcoin Knots
FROM base AS builder

RUN apk --no-cache add \
    autoconf \
    automake \
    boost-dev \
    build-base \
    chrpath \
    file \
    gnupg \
    git \
    libevent-dev \
    libressl \
    libtool \
    linux-headers \
    sqlite-dev \
    zeromq-dev

ENV BITCOIN_SOURCE_DIR=/bitcoin/src \
    SIGS_REPO_URL="https://github.com/bitcoinknots/guix.sigs.git" \
    SIGS_CLONE_DIR="guix.sigs" \
    VERIFY_SCRIPT_URL="https://raw.githubusercontent.com/bitcoinknots/bitcoin/v${BITCOIN_VERSION}/contrib/verify-binaries/verify.py" \
    ADDRESS="https://bitcoinknots.org/files/${BITCOIN_VERSION%%.*}.x/${BITCOIN_VERSION}"

WORKDIR /bitcoin
COPY ${BITCOIN_VERSION}/alpine/verify-${BITCOIN_VERSION%.*}.py .

RUN set -ex \
  && echo "$BITCOIN_VERSION" \
  && wget ${ADDRESS}/bitcoin-${BITCOIN_VERSION}.tar.gz \
  && wget ${ADDRESS}/SHA256SUMS \
  && wget ${ADDRESS}/SHA256SUMS.asc \
  && git clone ${SIGS_REPO_URL} ${SIGS_CLONE_DIR} \
  && gpg --import "${SIGS_CLONE_DIR}"/builder-keys/* \
  && ./verify-${BITCOIN_VERSION%.*}.py bin SHA256SUMS \
    "bitcoin-${BITCOIN_VERSION}.tar.gz" \
  && mkdir -p ${BITCOIN_SOURCE_DIR} \
  && tar -xzf "bitcoin-${BITCOIN_VERSION}.tar.gz" -C ${BITCOIN_SOURCE_DIR} \
  && rm -rf ${SIGS_CLONE_DIR}

WORKDIR "${BITCOIN_SOURCE_DIR}/bitcoin-${BITCOIN_VERSION}"

RUN ./autogen.sh \
    && ./configure \
    --prefix=${BITCOIN_PREFIX} \
    --mandir=/usr/share/man \
    --disable-tests \
    --disable-bench \
    --disable-fuzz-binary \
    --disable-ccache \
    --with-gui=no \
    --with-utils \
    --without-libs \
    --with-sqlite=yes \
    --with-daemon \
    && make -j`nproc` -C src bitcoind bitcoin-cli bitcoin-tx \
    && make -j`nproc` install \
    && strip ${BITCOIN_PREFIX}/bin/bitcoin-cli \
    && strip ${BITCOIN_PREFIX}/bin/bitcoin-tx \
    && strip ${BITCOIN_PREFIX}/bin/bitcoind

# Build stage for compiled artifacts
FROM base AS runtime

ARG UID=100
ARG GID=101

LABEL maintainer.0="Cameron White (@slvrfn)"

RUN addgroup bitcoin --gid ${GID} --system \
    && adduser --uid ${UID} --system bitcoin --ingroup bitcoin \
    && apk --no-cache add \
        libevent \
        libzmq \
        shadow \
        sqlite-libs \
        su-exec

ENV BITCOIN_DATA=/bitcoin/.bitcoin \
    PATH=${BITCOIN_PREFIX}/bin:$PATH

COPY --from=builder /opt /opt
COPY ${BITCOIN_VERSION}/alpine/docker-entrypoint.sh /entrypoint.sh

VOLUME ["/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]

RUN bitcoind -version | grep "Bitcoin Knots daemon version v${BITCOIN_VERSION}"

CMD ["bitcoind"]

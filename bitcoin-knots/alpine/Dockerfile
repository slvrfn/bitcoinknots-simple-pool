# common back image (allows ENV variable sharing)
FROM alpine:3.21 AS base

ARG BITCOIN_VERSION
RUN test -n "$BITCOIN_VERSION" # make sure version is provided and not empty

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
    SIGS_CLONE_DIR="guix.sigs"

WORKDIR /bitcoin

COPY bitcoin-knots/verify.py .

RUN set -ex \
  && if echo $BITCOIN_VERSION | grep -q "rc" ; then \
         export VERIFY_VERSION=$(echo $BITCOIN_VERSION | sed 's/\(.*\)rc\([0-9]*\)/\1-rc\2/'); \
         export ADDRESS="https://bitcoinknots.org/files/${VERIFY_VERSION%%.*}.x/${BITCOIN_VERSION%%rc*}/test.rc${BITCOIN_VERSION##*rc}"; \
       else \
         export VERIFY_VERSION=$BITCOIN_VERSION; \
         export ADDRESS="https://bitcoinknots.org/files/${VERIFY_VERSION%%.*}.x/${VERIFY_VERSION}"; \
       fi \
  && echo "$VERIFY_VERSION" \
  && wget ${ADDRESS}/bitcoin-${BITCOIN_VERSION}.tar.gz \
  && wget ${ADDRESS}/SHA256SUMS \
  && wget ${ADDRESS}/SHA256SUMS.asc \
  && git clone ${SIGS_REPO_URL} ${SIGS_CLONE_DIR} \
  && gpg --import "${SIGS_CLONE_DIR}"/builder-keys/* \
  && ./verify.py bin SHA256SUMS "bitcoin-${BITCOIN_VERSION}.tar.gz" \
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

COPY bitcoin-knots/alpine/docker-entrypoint.sh /entrypoint.sh

VOLUME ["/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]

RUN bitcoind -version | grep "Bitcoin Knots .*version v${BITCOIN_VERSION}"

CMD ["bitcoind"]

# common back image (allows ENV variable sharing)
FROM debian:bookworm-20250520-slim AS base

ARG BITCOIN_VERSION

FROM base AS builder

LABEL maintainer.0="Cameron White (@slvrfn)"

RUN apt-get update -y \
  && apt-get install -y ca-certificates curl git gnupg gosu python3 wget --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ARG TARGETPLATFORM
ENV SIGS_REPO_URL="https://github.com/bitcoinknots/guix.sigs.git" \
    SIGS_CLONE_DIR="guix.sigs" \
    TMPDIR="/tmp/bitcoin_verify_binaries"

COPY bitcoin-knots/verify.py .

RUN set -ex \
  && if echo $BITCOIN_VERSION | grep -q "rc" ; then \
       VERIFY_VERSION=$(echo $BITCOIN_VERSION | sed 's/\(.*\)rc\([0-9]*\)/\1-rc\2/'); \
     else \
       VERIFY_VERSION=$BITCOIN_VERSION; \
     fi \
  && echo "$VERIFY_VERSION" \
  && if [ "${TARGETPLATFORM}" = "linux/amd64" ]; then export TARGETPLATFORM=x86_64-linux-gnu; fi \
  && if [ "${TARGETPLATFORM}" = "linux/arm64" ]; then export TARGETPLATFORM=aarch64-linux-gnu; fi \
  && if [ "${TARGETPLATFORM}" = "linux/arm/v7" ]; then export TARGETPLATFORM=arm-linux-gnueabihf; fi \
  && git clone ${SIGS_REPO_URL} ${SIGS_CLONE_DIR} \
  && gpg --import "${SIGS_CLONE_DIR}"/builder-keys/* \
  && ./verify.py --min-good-sigs 6 pub "${VERIFY_VERSION}-linux" \
  && tar -xzf "${TMPDIR}.${VERIFY_VERSION}-linux/bitcoin-${BITCOIN_VERSION}-${TARGETPLATFORM}.tar.gz" -C /opt \
  && rm -rf ${SIGS_CLONE_DIR} \
  && rm -rf ${TMPDIR} \
  && rm -rf /opt/bitcoin-${BITCOIN_VERSION}/bin/bitcoin-qt

# Second stage
FROM base AS runtime

ARG UID=101
ARG GID=101

ENV BITCOIN_DATA=/bitcoin/.bitcoin
ENV PATH=/opt/bitcoin-${BITCOIN_VERSION}/bin:$PATH

RUN groupadd --gid ${GID} bitcoin \
  && if echo "$BITCOIN_VERSION" | grep -q "rc"; then \
       PADDED_VERSION=$(echo $BITCOIN_VERSION | sed 's/\([0-9]\+\)\.\([0-9]\+\)rc/\1.\2.0rc/'); \
     else \
       PADDED_VERSION=$BITCOIN_VERSION; \
     fi \
  && echo "Padded version: $PADDED_VERSION" \
  && useradd --create-home --no-log-init -u ${UID} -g ${GID} bitcoin \
  && apt-get update -y \
  && apt-get install -y gosu --no-install-recommends \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=builder /opt/bitcoin-${BITCOIN_VERSION} /opt/bitcoin-${BITCOIN_VERSION}

COPY bitcoin-knots/docker-entrypoint.sh /entrypoint.sh

VOLUME ["/bitcoin/.bitcoin"]

EXPOSE 8332 8333 18332 18333 18443 18444 38333 38332

ENTRYPOINT ["/entrypoint.sh"]

RUN bitcoind -version | grep "Bitcoin Knots .*version v${PADDED_VERSION}"

CMD ["bitcoind"]

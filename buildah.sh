#!/usr/bin/env bash
set -e 
# Define variables
DISTRO="alpine"
DISTRO_VARIANT="3.17"
BACKUPPC_VERSION="4.4.0"

BACKUPPC_XS_VERSION="0.62"
PAR2_VERSION="v0.8.0"
RSYNC_BPC_VERSION="3.1.3.0"
USER_BACKUPPC="1000"
GROUP_BACKUPPC="1000"

# Create a new container from the base image
ctr=$(buildah from docker.io/tiredofit/nginx:${DISTRO}-${DISTRO_VARIANT})

# Set metadata
buildah config --label maintainer="Dave Conroy (github.com/tiredofit)" $ctr

# Set environment variables
buildah config --env BACKUPPC_VERSION=${BACKUPPC_VERSION} \
                --env BACKUPPC_XS_VERSION=${BACKUPPC_XS_VERSION} \
                --env PAR2_VERSION=${PAR2_VERSION} \
                --env RSYNC_BPC_VERSION=${RSYNC_BPC_VERSION} \
                --env CONTAINER_ENABLE_PERMISSIONS=TRUE \
                --env USER_BACKUPPC=${USER_BACKUPPC} \
                --env GROUP_BACKUPPC=${GROUP_BACKUPPC} \
                --env NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
                --env NGINX_LISTEN_PORT=80 \
                --env NGINX_USER=backuppc \
                --env NGINX_GROUP=backuppc \
                --env NGINX_SITE_ENABLED=backuppc \
                --env CONTAINER_ENABLE_MESSAGING=TRUE \
                --env IMAGE_NAME="tiredofit/backuppc" \
                --env IMAGE_REPO_URL="https://github.com/tiredofit/docker-backuppc/" $ctr

# Run installation commands
buildah run $ctr -- /bin/bash -c 'source /assets/functions/00-container \
    && set -x \
    && addgroup -S -g ${GROUP_BACKUPPC} backuppc \
    && adduser -D -S -h /home/backuppc -s /sbin/nologin -G backuppc -g "backuppc" -u ${USER_BACKUPPC} backuppc \
    && addgroup zabbix backuppc \
    && package update \
    && package upgrade \
    && package install .backuppc-build-deps \
                    autoconf \
                    automake \
                    acl-dev \
                    build-base \
                    bzip2-dev \
                    expat-dev \
                    g++ \
                    gcc \
                    git \
                    make \
                    patch \
                    perl-dev \
                    perl-app-cpanminus \
    && package install .backuppc-run-deps \
                    bzip2 \
                    expat \
                    gzip \
                    fcgiwrap \
                    iputils \
                    libgomp \
                    openssh \
                    openssl \
                    perl \
                    perl-archive-zip \
                    perl-cgi \
                    perl-file-listing \
                    perl-json-xs \
                    perl-time-parsedate \
                    perl-xml-rss \
                    pigz \
                    rrdtool \
                    rsync \
                    samba-client \
                    spawn-fcgi \
                    sudo \
                    ttf-dejavu \
    && cpanm -M https://cpan.metacpan.org install \
                Net::FTP \
                Net::FTP::AutoReconnect \
    && mkdir -p /usr/src/pbzip2 \
    && curl -ssL https://launchpad.net/pbzip2/1.1/1.1.13/+download/pbzip2-1.1.13.tar.gz | tar xvfz - --strip=1 -C /usr/src/pbzip2 \
    && cd /usr/src/pbzip2 \
    && make -j$(nproc) \
    && make install \
    && clone_git_repo https://github.com/backuppc/backuppc-xs.git ${BACKUPPC_XS_VERSION} \
    && perl Makefile.PL \
    && make -j$(nproc) \
    && make test \
    && make install \
    && clone_git_repo https://github.com/backuppc/rsync-bpc.git ${RSYNC_BPC_VERSION} \
    && ./configure \
    && make reconfigure \
    && make -j$(nproc) \
    && make install \
    && clone_git_repo https://github.com/Parchive/par2cmdline.git ${PAR2_VERSION} \
    && ./automake.sh \
    && ./configure \
    && make -j$(nproc) \
    && make check \
    && make install \
    && mkdir -p /assets/install \
    && curl -sSL https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz | tar xvfz - --strip 1 -C /assets/install \
    && apk add patch \
    && curl -o /assets/install/patchfile.patch https://github.com/backuppc/backuppc/commit/2c9270b9b849b2c86ae6301dd722c97757bc9256.patch \
    && cd /assets/install \
    && patch -p1 < patchfile.patch \
    && apk del patch \
    && apk cache clean \
    && package remove .backuppc-build-deps \
    && package cleanup \
    && rm -rf /root/.cpanm /tmp/* /usr/src/*'

# Copy installation files
buildah copy $ctr install/ /

# Commit the changes to the image
buildah commit $ctr my-backuppc-image

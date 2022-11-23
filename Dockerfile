FROM docker.io/tiredofit/nginx:alpine-3.17
LABEL maintainer="Dave Conroy (github.com/tiredofit)"

ENV BACKUPPC_VERSION=4.4.0 \
    BACKUPPC_XS_VERSION=0.62 \
    PAR2_VERSION=v0.8.0 \
    RSYNC_BPC_VERSION=3.1.3.0 \
    NGINX_ENABLE_CREATE_SAMPLE_HTML=FALSE \
    NGINX_USER=backuppc \
    NGINX_GROUP=backuppc \
    NGINX_SITE_ENABLED=backuppc \
    CONTAINER_ENABLE_MESSAGING=TRUE \
    IMAGE_NAME="tiredofit/backuppc" \
    IMAGE_REPO_URL="https://github.com/tiredofit/docker-backuppc/"

RUN source /assets/functions/00-container && \
    set -x && \
    apk update && \
    apk upgrade && \
    apk add -t .backuppc-build-deps \
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
                && \
    \
    apk add -t .backuppc-run-deps \
                bzip2 \
                expat \
                gzip \
                fcgiwrap \
                iputils \
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
                && \
    \
    # Install Perl Modules not included in package
    cpanm -M https://cpan.metacpan.org install \
    Net::FTP \
    Net::FTP::AutoReconnect \
    && \
    \
    # Compile and install Parallel BZIP
    mkdir -p /usr/src/pbzip2 && \
    curl -ssL https://launchpad.net/pbzip2/1.1/1.1.13/+download/pbzip2-1.1.13.tar.gz | tar xvfz - --strip=1 -C /usr/src/pbzip2 && \
    cd /usr/src/pbzip2 && \
    make && \
    make install && \
    \
    # Compile and install BackupPC:XS
    clone_git_repo https://github.com/backuppc/backuppc-xs.git ${BACKUPPC_XS_VERSION} && \
    perl Makefile.PL && \
    make && \
    make test && \
    make install && \
    \
    # Compile and install Rsync (BPC version)
    clone_git_repo https://github.com/backuppc/rsync-bpc.git ${RSYNC_BPC_VERSION} && \
    ./configure && \
    make reconfigure && \
    make && \
    make install && \
    \
    # Compile and install PAR2
    clone_git_repo https://github.com/Parchive/par2cmdline.git ${PAR2_VERSION} && \
    ./automake.sh && \
    ./configure && \
    make && \
    make check && \
    make install && \
    \
    # Get BackupPC, it will be installed at runtime to allow dynamic upgrade of existing config/pool
    curl -o /usr/src/BackupPC-$BACKUPPC_VERSION.tar.gz -L https://github.com/backuppc/backuppc/releases/download/$BACKUPPC_VERSION/BackupPC-$BACKUPPC_VERSION.tar.gz && \
    \
    # Prepare backuppc home
    mkdir -p /home/backuppc && \
    \
    # Mark the docker as not runned yet, to allow entrypoint to do its stuff
    touch /firstrun && \
    \
    # Cleanup
    apk del .backuppc-build-deps && \
    rm -rf /root/.cpanm /usr/src/backuppc-xs /usr/src/rsync-bpc /usr/src/par2cmdline /usr/src/pbzip2 && \
    rm -rf /tmp/* && \
    rm -rf /var/cache/apk/*

### Add Folders
COPY install/ /

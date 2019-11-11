FROM docker:17.12.0-ce as static-docker-source

FROM ubuntu:18.04
LABEL maintainer="https://github.com/hrcc"

ENV DEBIAN_FRONTEND noninteractive

ENV LANG C.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL C.UTF-8
# good colors for most applications
ENV TERM xterm
# avoid million NPM install messages
ENV npm_config_loglevel warn 
# allow installing when the main user is root
ENV npm_config_unsafe_perm true
# version of the Google Cloud SDK
ENV CLOUD_SDK_VERSION 200.0.0

# INSTALL
RUN apt-get update \
    && apt-get install -y apt-utils curl wget unzip git software-properties-common lsb-release

# Dockerize v0.6.1
RUN wget https://github.com/jwilder/dockerize/releases/download/v0.6.1/dockerize-linux-amd64-v0.6.1.tar.gz \
    && tar -C /usr/local/bin -xzvf dockerize-linux-amd64-v0.6.1.tar.gz \
    && rm dockerize-linux-amd64-v0.6.1.tar.gz

# PHP 7.3
RUN add-apt-repository -y ppa:ondrej/php && apt-get update \
    && apt-get install -y libpq-dev libpng-dev php-pear \
    php7.3-dev php7.3-fpm php7.3-cli php7.3-gd php7.3-bcmath \
    php7.3-mysql php7.3-sqlite3 php7.3-imap php7.3-mbstring \       
    php7.3-json php7.3-curl php7.3-gd php7.3-gmp php7.3-zip php-redis php7.2-xml \
    php-yaml php7.3-xml php-mongodb imagemagick php-imagick php7.3-xdebug \ 
    && mkdir /run/php

# Composer
RUN php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

# MySQL
RUN apt-get update && apt-get install -y mysql-client 

# Node.js v12
RUN curl --silent --location https://deb.nodesource.com/setup_12.x | bash - \
    && apt-get install nodejs -y

# "fake" dbus address to prevent errors
# https://github.com/SeleniumHQ/docker-selenium/issues/87
ENV DBUS_SESSION_BUS_ADDRESS=/dev/null

# Cypress.js dependencies
RUN apt-get update && \
    apt-get install -y libgtk2.0-0 libnotify-dev libgconf-2-4 \
    libnss3 libxss1 libasound2 xvfb

# Google Cloud SDK
# copied from https://hub.docker.com/r/google/cloud-sdk/~/dockerfile/
RUN export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0 && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true && \
    gcloud config set metrics/environment github_docker_image 

# Cloud SQL Proxy
ADD https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 /usr/local/bin/cloud_sql_proxy
RUN chmod +x /usr/local/bin/cloud_sql_proxy

# CircleCI
COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker
ADD https://circle-downloads.s3.amazonaws.com/releases/build_agent_wrapper/circleci /usr/local/bin/circleci
RUN chmod +x /usr/local/bin/circleci

# Lokalise
ADD https://s3-eu-west-1.amazonaws.com/lokalise-assets/cli/lokalise-0.711-linux-amd64.tgz /tmp
RUN cd tmp && tar xvfz lokalise*.tgz && mv /tmp/lokalise /usr/local/bin

# Install Google Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -
RUN sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
RUN apt-get update && apt-get install -y google-chrome-stable

# Install Goss
RUN curl -fsSL https://goss.rocks/install | sh

# Cleanup for smaller image size
RUN apt-get remove -y --purge apt-utils software-properties-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

FROM alpine:latest

RUN apk --no-cache add bash

# Use bash for the shell
SHELL ["/bin/bash", "-c"]

# Install Node v16 (LTS)
RUN apk --no-cache add nodejs npm

# Install Ruby 3.0
RUN apk --no-cache add ruby ruby-dev
# Install a whole bunch of other things we're going to need at some point...
RUN apk --no-cache add libssl1.1 libpq imagemagick ffmpeg \
        icu-libs libidn yaml file ca-certificates tzdata readline gcc tini make \
        git icu-dev libidn-dev libpq-dev shared-mime-info musl-dev zlib-dev g++ python3

RUN npm install -g npm@latest && \
    npm install -g yarn && \
    gem install bundler

COPY Gemfile* package.json yarn.lock /opt/mastodon/

#RUN cd /opt/mastodon && \
  #bundle config set --local deployment 'true' && \
  #bundle config set --local without 'development test' && \
  #bundle config set silence_root_warning true && \
    #bundle install -j"$(nproc)" && \
    #yarn install --pure-lockfile

RUN cd /opt/mastodon && \
  bundle config set --local without 'development test' && \
  bundle config set silence_root_warning true && \
    bundle install -j"$(nproc)" && \
    yarn install --pure-lockfile

# Add more PATHs to the PATH
ENV PATH="${PATH}:/opt/mastodon/bin"

# Create the mastodon user
ARG UID=992
ARG GID=992
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
#RUN echo "Etc/UTC" > /etc/localtime && \
    #apk --no-cache add whois wget && \
    #addgroup --gid $GID mastodon && \
    #useradd -m -u $UID -g $GID -d /opt/mastodon mastodon && \
    #echo "mastodon:$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256)" | chpasswd

RUN echo "Etc/UTC" > /etc/localtime && \
    apk --no-cache add whois wget && \
    addgroup --gid $GID mastodon && \
    adduser -u $UID -G mastodon -D -h /opt/mastodon mastodon #&& \
    #echo "mastodon:$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 | mkpasswd -s -m sha-256)" | chpasswd

# Install mastodon runtime deps
#RUN apt-get update && \
    #apt-get -y --no-install-recommends install \
    #libssl1.1 libpq5 imagemagick ffmpeg \
    #libicu66 libidn11 libyaml-0-2 \
    #file ca-certificates tzdata libreadline8 gcc tini apt-utils && \
    #ln -s /opt/mastodon /mastodon && \
    #gem install bundler && \
    #rm -rf /var/cache && \
    #rm -rf /var/lib/apt/lists/*
RUN ln -s /opt/mastodon /mastodon && \
    gem install bundler && \
    rm -rf /var/cache && \
    rm -rf /var/lib/apt/lists/*

# Copy over mastodon source, and dependencies from building, and set permissions
COPY --chown=mastodon:mastodon . /opt/mastodon
#COPY --from=build-dep --chown=mastodon:mastodon /opt/mastodon /opt/mastodon

# Run mastodon services in prod mode
ENV RAILS_ENV="production"
ENV NODE_ENV="production"

# Tell rails to serve static files
ENV RAILS_SERVE_STATIC_FILES="true"
ENV BIND="0.0.0.0"

# Set the run user
USER mastodon

# Precompile assets
RUN cd ~ && \
    OTP_SECRET=precompile_placeholder SECRET_KEY_BASE=precompile_placeholder rails assets:precompile && \
    yarn cache clean

# Set the work dir and the container entry point
WORKDIR /opt/mastodon
ENTRYPOINT ["/usr/bin/tini", "--"]
EXPOSE 3000 4000

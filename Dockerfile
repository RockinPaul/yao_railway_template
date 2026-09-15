# Yao Agents — self-hosted hub for agents, workspaces and a task board
# (https://github.com/YaoApp/yao). Upstream publishes multi-arch images, so this is a
# thin pin plus an entrypoint that makes a first boot safe on a public URL.
ARG YAO_VERSION=1.0.0-rc22
FROM yaoapp/yao:${YAO_VERSION}

# The base image runs as `yao`; the entrypoint needs root briefly to prepare the volume,
# then drops back with su-exec. socat gives the engine a dual-stack listener: Yao binds
# IPv4 only (YAO_HOST of `::` or `[::]` exits with "Host not found"), and 0.0.0.0 is
# invisible on Railway's IPv6-only private network.
USER root
RUN apk add --no-cache su-exec socat tini

# YAO_ROOT beats the app's own .env and the working directory, and it is a subdirectory
# of the mount because a Railway volume root holds lost+found and `yao init` refuses a
# non-empty directory. Not /data/app: that is the base image's VOLUME path, which a
# local `docker run` would shadow with an anonymous volume.
ENV PORT=8080 \
    YAO_ROOT=/data/yao \
    YAO_ENGINE_PORT=5099

COPY --chmod=755 entrypoint.sh /usr/local/bin/railway-entrypoint
WORKDIR /data/yao
EXPOSE 8080
# tini reaps the socat relay and anything the engine spawns.
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/railway-entrypoint"]

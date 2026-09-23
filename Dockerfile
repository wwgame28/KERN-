FROM ghcr.io/openclaw/openclaw:latest

USER root
COPY start.sh /usr/local/bin/openclaw-amvera-start
COPY openclaw.json /opt/openclaw/openclaw.json
RUN chmod 0755 /usr/local/bin/openclaw-amvera-start \
    && mkdir -p /data /opt/openclaw \
    && chown -R node:node /data /opt/openclaw

USER node
ENV HOME=/home/node \
    OPENCLAW_HOME=/home/node \
    OPENCLAW_STATE_DIR=/data \
    OPENCLAW_CONFIG_DIR=/data \
    OPENCLAW_CONFIG_PATH=/data/openclaw.json \
    OPENCLAW_WORKSPACE_DIR=/data/workspace \
    OPENCLAW_GATEWAY_PORT=18789 \
    OPENCLAW_DISABLE_BONJOUR=1

EXPOSE 18789
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/usr/local/bin/openclaw-amvera-start"]

FROM ghcr.io/openclaw/openclaw:latest

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN npm i -g @openclaw/clawhub

ENTRYPOINT ["/entrypoint.sh"]

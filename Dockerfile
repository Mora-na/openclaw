FROM ghcr.io/openclaw/openclaw:latest

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN npm i -g clawhub

ENTRYPOINT ["/entrypoint.sh"]

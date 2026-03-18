FROM ghcr.io/openclaw/openclaw:latest

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN npm i -g clawhub
RUN pip install akshare

ENTRYPOINT ["/entrypoint.sh"]

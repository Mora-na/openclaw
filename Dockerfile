FROM ghcr.io/openclaw/openclaw:latest

USER root

ENV TZ=Asia/Shanghai
RUN if [ -e /usr/share/zoneinfo/Asia/Shanghai ]; then \
      ln -snf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
      echo Asia/Shanghai > /etc/timezone; \
    fi

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN npm install -g n \
    && n 22 \
    && node -v \
    && npm -v \
    && npm uninstall -g n
RUN npm i -g clawhub

ENTRYPOINT ["/entrypoint.sh"]

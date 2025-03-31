# 使用指定的基础镜像作为构建阶段的基础镜像，该镜像包含了所有必要的构建环境和依赖项
FROM debian:bookworm-20250317-slim

RUN apt-get update && \
    apt-get install -y  curl wget jq tar ca-certificates && \
    mkdir -p /opt/ppp && \
    mkdir -p /etc/caddy

ARG CADDY_VERSION="2.9.1"

# 下载并安装 Caddy
RUN wget -O /tmp/caddy.tar.gz "https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz" && \
    cd /tmp && \
    tar -xzf caddy.tar.gz && \
    install -D -m 755 caddy /usr/local/bin/caddy && \
    rm -f caddy.tar.gz

COPY opt/pppd.sh /opt/ppp/pppd.sh
COPY opt/appsettings.json /opt/ppp/appsettings.json
COPY opt/Caddyfile /etc/caddy/Caddyfile

WORKDIR /opt/ppp
RUN chmod a+x ./pppd.sh  \
    && apt-get autoremove -y  \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/*
# 暴露 9988 端口
EXPOSE 9988

# 以前台模式运行 Caddy，监听 9988 端口
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]



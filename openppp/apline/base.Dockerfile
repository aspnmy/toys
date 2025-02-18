# 使用alpine:3.21.3 作为基础镜像
FROM alpine:3.21.3 AS base

# 阻止交互式提示
ARG DEBIAN_FRONTEND=noninteractive

# 设置工作目录
WORKDIR /opt

# 更新系统并安装必要的构建工具和库
RUN apk update && apk add --no-cache \
    autoconf \
    automake \
    build-base \
    ca-certificates \
    clang \
    cmake \
    curl \
    g++ \
    gcc \
    gdb \
    git \
    icu-dev \
    krb5-dev \
    libressl-dev \
    libunwind \
    net-tools \
    openssl \
    unzip \
    zip
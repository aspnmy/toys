#!/bin/bash

repourl="docker.io"
image="openppp2"
tag="base,boodle,env,jemalloc,openssl"
arch="amd64"
repousr="aspnmy"
dockerfile="base.Dockerfile,boodle.Dockerfile,env.Dockerfile,jemalloc.Dockerfile,openssl.Dockerfile"
# 重试逻辑
max_retries=5
retry_count=0

processDockerfiles() {
    IFS=',' read -ra dockerfiles <<< "$dockerfile"
    IFS=',' read -ra tags <<< "$tag"
    for index in "${!dockerfiles[@]}"; do
        buildImage "${dockerfiles[$index]}" "${tags[$index]}"
        pushImage "${tags[$index]}"
    done
}

buildImage() {
    local dockerfile=$1
    local tag=$2
    while [ $retry_count -lt $max_retries ]; do
        docker build -t $repourl/$repousr/$image:$tag --build-arg ARCH=$arch -f $dockerfile .
        if [ $? -eq 0 ]; then
            return 0
        fi
        retry_count=$((retry_count + 1))
        echo "构建镜像失败，重试 $retry_count/$max_retries 次..."
        sleep 5
    done
    echo "镜像构建失败，已达到最大重试次数"
    exit 1
}

pushImage() {
    local tag=$1
    while [ $retry_count -lt $max_retries ]; do
        docker push $repourl/$repousr/$image:$tag
        if [ $? -eq 0 ]; then
            return 0
        fi
        retry_count=$((retry_count + 1))
        echo "推送镜像失败，重试 $retry_count/$max_retries 次..."
        sleep 5
    done
    echo "镜像推送失败，已达到最大重试次数"
    exit 1
}

main() {
    processDockerfiles
}

echo "镜像推送失败，已达到最大重试次数"
exit 1

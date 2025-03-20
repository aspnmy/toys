# 使用指定的基础镜像作为构建阶段的基础镜像，该镜像包含了所有必要的构建环境和依赖项
FROM alpine:3.21.3

RUN apk update && apk add --no-cache curl wget jq
ADD opt /opt

RUN chmod a+x /opt/ppp.sh &&   \
    mv /opt/ppp /etc/ && \
    chmod a+x /etc/ppp/ppp 
    
# 设置启动脚本为容器启动时运行的命令
 ENTRYPOINT ["/etc/ppp/ppp"]

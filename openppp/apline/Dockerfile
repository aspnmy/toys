# 使用指定的基础镜像作为构建阶段的基础镜像，该镜像包含了所有必要的构建环境和依赖项
FROM aspnmy/openppp2:alpine_v3.21.3_base 



# 设置工作目录
WORKDIR /opt




# 设置启动脚本为容器启动时运行的命令
ENTRYPOINT ["./opt/ppp.sh"]

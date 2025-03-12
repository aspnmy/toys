# 快速开始

## 服务器端配置

1. 找到一台服务器来部署 openppp2 服务器

2. 连接到服务器。

3. 远程下载 openppp2 压缩文件。

4. 修改 openppp2 压缩文件中的 appsettings.json 模板文件。

    1. 如果不需要将此服务器用作 SNIProxy 服务器，请删除 "cdn" 参数。

    2. 如果您的服务器有 256MiB+ 内存且磁盘 I/O 速度不满足 4K 块，请删除 vmem 参数。

    3. 如果您的服务器有超过 1 个线程，最好将 cocurrent 设置为线程数。

    4. 设置服务器监听的 IP 地址

        1. 如果您决定使用分配给服务器的所有 IP，请将 ip.interface 和 ip.public 更改为 "::"

            ```json
            "ip": {
                "interface": "::",
                "public": "::"
            }
            ```
        2. 如果您决定只使用一个 IP 地址，请将 ip.interface 和 ip.public 更改为您要使用的 IP。

        3. 在一些特殊情况下，公共 IP 是通过路由分配的，您应该将接口更改为 "::" 并将公共更改为将要使用的 IP 地址。

        4. 讨厌 IPv6？将所有 "::" 替换为 "0.0.0.0"

    5. 通过修改 tcp.listen.port 和 udp.listen.port 设置 TCP 和 UDP 端口

    6. 删除整个 websocket 参数，因为 TCP 连接足够安全，可以面对审查。（Websocket 连接应在一些特殊情况下使用）

    7. 设置一些服务器运行参数
    
        1. server.log 是存储连接日志的路径。如果您不需要日志，请设置为 "/dev/null"

        2. 删除 server 块中的以下参数。

            ```json
            
            "server": {
                "log": "/dev/null"
            }

            ```
    
    8. 使用 `screen -S` 让 openppp2 在后台运行

    9. 记得 chmod +x ！

    10. 启动服务器

## 客户端配置

1. 只要客户端在 PC 上运行或客户端设备使用 eMMc 作为存储，请删除 vmem 参数。

2. 设置 udp.static.server

    - IP:PORT

    - DOMAIN:PORT

    - DOMAIN[IP]:PORT

3. 将 client.guid 设置为一个完全随机的，请确保没有其他客户端与您使用的相同 GUID。

4. 设置 client.server

    - ppp://IP:PORT

    - ppp://DOMAIN:PORT

    - ppp://DOMAIN[IP]:PORT

5. 删除 client.bandwidth 以释放 openppp2 的全速

6. 删除 mappings 参数

## 客户端 CLI 注意事项

1. Windows 上的 TUN 网关应为 x.x.x.0

2. 只有添加 --tun-static=yes，UDP 流才会分开传输。

3. 如果 --block-quic=yes，无论 --tun-static 设置为何，都不会有任何 QUIC 流。

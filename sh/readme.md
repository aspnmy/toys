# 配置说明

- 示例

  ```json
  {
      "concurrent": 2,
      "cdn": [ 80, 443 ],
      "key": {
          "kf": 154543927,
          "kx": 128,
          "kl": 10,
          "kh": 12,
          "protocol": "aes-128-cfb",
          "protocol-key": "N6HMzdUs7IUnYHwq",
          "transport": "aes-256-cfb",
          "transport-key": "HWFweXu2g5RVMEpy",
          "masked": false,
          "plaintext": false,
          "delta-encode": false,
          "shuffle-data": false
      },
      "ip": {
          "public": "192.168.0.24",
          "interface": "192.168.0.24"
      },
      "vmem": {
          "size": 4096,
          "path": "./{}"
      },
      "tcp": {
          "inactive": {
              "timeout": 300
          },
          "connect": {
              "timeout": 5
          },
          "listen": {
              "port": 20000
          },
          "turbo": true,
          "backlog": 511,
          "fast-open": true
      },
      "udp": {
          "inactive": {
              "timeout": 72
          },
          "dns": {
              "timeout": 4,
              "redirect": "0.0.0.0"
          },
          "listen": {
              "port": 20000
          },
          "static": {
              "keep-alived": [ 1, 5 ],
              "dns": true,
              "quic": true,
              "icmp": true,
              "server": "192.168.0.24:20000"
          }
      },
      "websocket": {
          "host": "starrylink.net",
          "path": "/tun",
          "listen": {
              "ws": 20080,
              "wss": 20443
          },
          "ssl": {
              "certificate-file": "starrylink.net.pem",
              "certificate-chain-file": "starrylink.net.pem",
              "certificate-key-file": "starrylink.net.key",
              "certificate-key-password": "test",
              "ciphersuites": "TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256"
          },
          "verify-peer": true,
          "http": {
              "error": "状态码：404；未找到",
              "request": {
                  "Cache-Control": "no-cache",
                  "Pragma": "no-cache",
                  "Accept-Encoding": "gzip, deflate",
                  "Accept-Language": "zh-CN,zh;q=0.9",
                  "Origin": "http://www.websocket-test.com",
                  "Sec-WebSocket-Extensions": "permessage-deflate; client_max_window_bits",
                  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0"
              },
              "response": {
                  "Server": "Kestrel"
              }
          }
      },
      "server": {
          "log": "./ppp.log",
          "node": 1,
          "subnet": true,
          "mapping": true,
          "backend": "ws://192.168.0.24/ppp/webhook",
          "backend-key": "HaEkTB55VcHovKtUPHmU9zn0NjFmC6tff"
      },
      "client": {
          "guid": "{F4569208-BB45-4DEB-B115-0FEA1D91B85B}",
          "server": "ppp://192.168.0.24:20000/",
          "bandwidth": 10000,
          "reconnections": {
              "timeout": 5
          },
          "paper-airplane": {
              "tcp": true
          },
          "http-proxy": {
              "bind": "192.168.0.24",
              "port": 8080
          },
          "mappings": [
              {
                  "local-ip": "192.168.0.24",
                  "local-port": 80,
                  "protocol": "tcp",
                  "remote-ip": "::",
                  "remote-port": 10001
              },
              {
                  "local-ip": "192.168.0.24",
                  "local-port": 7000,
                  "protocol": "udp",
                  "remote-ip": "::",
                  "remote-port": 10002
              }
          ]
      }
  }
  ```

- 服务器和客户端共享参数

    - .concurrent

		设置并发连接数量。

	- .vmem

		在磁盘上创建临时虚拟文件作为交换文件

		- .vmem.size

			指定创建的虚拟文件的大小。单位为KB

		- .vmem.path

			指定创建虚拟文件的路径。

	- .key

		加密和关键帧生成参数。

		- .key.kf

			类似于AES算法中的预共享IV值，kf值用于生成关键帧。

		- .key.kl & .key.kh

			这两个值应在[0..16]范围内，与关键帧位置相关。两者都应在服务器和客户端配置中设置，但不需要相同。

		- .key.kx
    
			此值应在[0..255]范围内，与帧填充相关，但不是填充长度或帧长度。

		- .key.protocol & .key.transport

			这两个值应在openssl-3.2.0/providers/implementations/include/prov/names.h中列出的算法名称中选择。

		- .key.protocol-key & .key.transport-key

			用于协议加密和传输加密的密钥字符串。

		- .key.masked
    
			原理类似于建立WebSocket连接时的掩码过程，但不是相同的过程。

		- .key.plain-text

			使用自开发算法将所有流量扭曲成可打印文本并集成熵控制。启用后，包大小将比原始大小大几倍。

		- .key.delta-encode

			使用自开发的delta编码算法，使连接更安全。消耗更多CPU时间

		- .key.shuffle-data

			将传输的二进制数据打乱。消耗更多CPU时间。

	- .ip

		指定openppp2服务器应绑定的IP地址。

		以下两个参数通常可以设置为"::"。

		- .ip.public

			设置openppp2服务器的公共IP
		
		- .ip.interface

			设置openppp2服务器监听的接口IP。

	- .tcp

		指定TCP连接相关参数。

		- .tcp.inactive.timeout

			指定服务器释放闲置TCP连接的时间长度。

		- .tcp.listen.port

            指定openppp2服务器监听TCP连接的端口。

    - .udp

        指定UDP连接相关参数。

        - .udp.inactive.timeout

            指定openppp2服务器在没有数据传输的情况下释放UDP端口的时间长度。

        - .udp.dns

            DNS解锁相关设置。你可以将所有DNS查询重定向到特定的DNS。
            
            - .udp.dns.timeout

                设置DNS查询的超时时间，单位为秒。

            - .udp.redirect

                默认值为0.0.0.0，这意味着没有重定向。

                所有到53端口的UDP流量将被重定向到此地址

        - .udp.static

            当CLI启用--tun-static选项时，UDP流量将与TCP流量分离。

            新建立的UDP连接将遵循此处设置的参数。

            - .udp.static.keep-alived

                此参数应为一个包含两个整数值的数组，这意味着客户端端口将在此期间平滑切换到另一个端口。

                前一个值不应大于后一个值。

                如果未指定或设置为[0, 0]，UDP端口将不会释放，这在某些特殊网络情况下可能会导致流量问题。

            - .udp.static.dns

                启用此参数后，openppp2客户端将通过UDP而不是TCP传输DNS查询。
            
            - .udp.static.quic

                允许通过UDP传输QUIC，--block-quic应设置为否。

            - .udp.static.icmp

                允许通过UDP传输ICMP

            - .udp.static.server

                UDP端点。接受以下三种格式
                
                1. IP:PORT (例如192.168.0.24:20000)

                2. 域名:PORT (例如localhost:20000)

                3. 域名[IP]:PORT (例如localhost[127.0.0.1]:20000)

		- .websocket.ssl

        指定使用wss协议连接openppp2服务器时的TLS参数。

        - .websocket.request

        指定使用ws或wss协议连接openppp2服务器时发送的HTTP请求头。

    - .websocket.response

    指定使用ws或wss协议连接openppp2服务器时响应的HTTP响应头。

  - .websocket.verify-peer

    验证客户端是否为openppp2客户端

  - .websocket.http

    使用WebSocket连接openppp2服务器时指定HTTP头。

  - 

- 仅服务器参数

  - .cdn

    启用此节点作为SNI代理节点。所有发送到此服务器的80/443端口的HTTP/HTTPS请求将被重定向到HTTP Host Head或SNI中的网站。

  - .tcp & .udp

    你只需修改.tcp.listen.port，该端口指定openppp2监听端口。 

  - .server

    这些参数指定服务器端配置。

    - .server.log

      设置存储VPN连接日志的位置。留空以禁用日志记录。 

    - .server.node

      如果你有多个节点管理，此值应不同以识别日志中的不同服务器。

    - .server.subnet

      启用此值后，所有客户端将进入一个子网并能够相互ping通或连接。
    
    - .server.mapping
    
      启用此值后，openppp2服务器能够作为反向代理服务器工作，并将内部客户端端口导出到公共网络。
    
    - .server.backend
    
      控制面板的地址。控制面板源代码在github.com/liulilittle/openppp2/go中提供
    
    - .server.backend-key
    
      用于验证与控制面板连接的密钥

- 仅客户端参数

  - .client

    指定客户端参数

    - .client.guid 

      在所有连接到openppp2服务器的客户端中，GUID字符串应保持唯一。

    - .client.server

      设置连接到的openppp2服务器。如果使用TCP连接，字符串应为"ppp://[ip_addr | domain]:port/"。如果使用WebSocket，只需将ppp替换为ws，然后添加WebSocket路径。

      请记住，不需要将IPv6地址用[]括起来。由于解析算法已被修改。

    - .client.bandwidth

      限制客户端带宽，单位为kbps。

    - .client.reconnections.timeout

      设置重连超时时间

    - .client.paper-airplane.tcp

      使用内核组件加速网络连接和流量。由于无法负担的开发者证书，内核组件未签名，这会导致反作弊软件报警。
    
    - .client.http-proxy
    
      设置客户端HTTP代理参数。
    
      - .client.http-proxy.bind
    
        设置HTTP代理监听的IP地址。
    
      - .client.http-proxy.port
    
        设置HTTP代理监听的端口。
    
    - .client.mappings
    
      设置客户端的frp功能。通过在向量中设置这些参数，客户端能够将其端口映射到外部openppp2服务器的特定端口 
    
      - .client.mappings.[n].local-ip
    
        请使用分配给TUN的虚拟地址。这样，openppp2服务器接收到的数据将通过已建立的连接发送到客户端。
    
      - .client.mappings.[n].local-port
    
        设置将在客户端映射到openppp2服务器端的端口。
    
      - .client.mappings.[n].protocol
    
        设置在openppp2服务器端接收的协议。
    
      - .client.mappings.[n].remote-ip
    
        设置openppp2服务器将监听的远程IP。
    
      - .client.mappings.[n].remote-port
    
        设置openppp2服务器将监听的远程端口。

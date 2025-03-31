# aarch64 不能执行ppp的debug

- 由于 ppp的库文件是x86_64的所以,直接在aarch64版本下执行可能会报错
```bash
bash: ./ppp:无法执行二进制文件: 可执行文件格式错误无法执行
# 确认ppp的库文件
# file ./ppp
# ./ppp: ELF 64-bit LSB pie executable, x86-64, version 1 (GNU/Linux), dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, BuildID[sha1]=9d3be5a905aff800dfdc7ea5a18fbdb9c10b29d6, for GNU/Linux 3.2.0, with debug_info, not stripped

# 如果是aarch版本的,确认ppp是否有缺失库
# ldd ./ppp
# 若有 not found 的库,安装对应 ARM64 版本的库:按下面命令安装缺失的aarch库
# sudo apt install <缺失的库名>:arm64

```

- 如果出现上面错误,可以尝试安装模拟器qemu,模拟执行ppp
```bash
sudo apt update
sudo apt install qemu-user-static binfmt-support
# 再重新尝试运行ppp,如果仍然不能运行,怎需要在aarch版本下重新编译
```

#  自用脚本
## autocheck.sh,适用于 Lightsail 检查流量超出自动关机脚本
```
bash <(curl -Ls https://raw.githubusercontents.com/rebecca554owen/toys/main/sh/autocheck.sh)
```
## bbr.sh,适用于 vps 加速
```
bash <(curl -Ls https://raw.githubusercontents.com/rebecca554owen/toys/main/sh/bbr.sh)
```
## get-py.py 适用于自动下载Python
```
bash <(curl -Ls https://raw.githubusercontents.com/rebecca554owen/toys/main/sh/get-py.sh)
```
## ppp.sh 适用于openppp2安装
```
bash <(curl -Ls https://raw.githubusercontents.com/aspnmy/toys/main/sh/ppp.sh)
```
## compose.yaml 适用于openppp2
```
mkdir openppp2
cd openppp2
curl -Ls https://raw.githubusercontents.com/rebecca554owen/toys/main/compose.yaml
docker compose up -d
```
## miaospeed 后端docker run 一键启动
```
docker run -d --name miaospeed-koipy --restart always --network host airportr/miaospeed:latest server -bind [::]:8766 -mtls -connthread 64 -token fulltclash -ipv6
```
## miaospeed 后端docker-compose 启动
```
mkdir miaospeed
cd miaospeed
curl -Ls https://raw.githubusercontents.com/rebecca554owen/toys/main/miaospeed/docker-compose.yaml
docker compose up -d
```
## Koipy 黑名单列表
```
https://raw.githubusercontents.com/rebecca554owen/toys/main/invireBlacklistDomain.txt
```
```
https://raw.githubusercontents.com/rebecca554owen/toys/main/invireBlacklistURL.txt
```
## clash-verge-rec.js 适用于mihomo-patry
```
https://raw.githubusercontents.com/rebecca554owen/toys/main/clash-verge-rec.js
```
## yaml.yaml 适用于mihomo-patry
```
https://raw.githubusercontents.com/rebecca554owen/toys/main/yaml.yaml
```

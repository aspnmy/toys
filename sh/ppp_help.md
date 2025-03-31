# ppp 常见指令
```bash
    ./ppp \
        --mode=[client|server] \
        --config=[./appsettings.json] \
        --lwip=[yes|no] \
        --nic=[en0] \
        --ngw=[0.0.0.0] \
        --tun=[ppp] \
        --tun-ip=[10.0.0.2] \
        --tun-gw=[10.0.0.1] \
        --tun-mux=[0] \
        --tun-mux-acceleration=[0,1,2,3] \
        --tun-mask=[30] \
        --tun-vnet=[yes|no] \
        --tun-host=[yes|no] \
        --tun-flash=[yes|no] \
        --tun-static=[yes|no] \
        --tun-ssmt=[[4]/[mq]] \
        --tun-route=[yes|no] \
        --tun-protect=[yes|no] \
        --tun-promisc=[yes|no] \
        --dns=[8.8.8.8,8.8.4.4] \
        --block-quic=[yes|no] \
        --bypass-iplist=[./ip.txt] \
        --auto-restart=[86400] \
        --auto-pull-iplist=[[ip.txt]/[CN]] \
        --dns-rules=[./dns-rules.txt] \
        --firewall-rules=[./firewall-rules.txt] 
Commands:
        ./ppp --help 
        ./ppp --pull-iplist [[ip.txt]/[CN]]
```

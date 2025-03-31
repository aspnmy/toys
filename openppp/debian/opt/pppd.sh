#!/bin/sh

# docker专用脚本
ppp_dir="/etc/ppp" # 定义安装目录

# 检测操作系统
OS=""
if [ -f /etc/alpine-release ]; then
    OS="Alpine"
elif [ -f /etc/redhat-release ]; then
    OS="CentOS"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

# 安装依赖
install_dependencies() {
    echo "检测到操作系统:$OS"
    
    case "$OS" in
        ubuntu | debian)
            echo "更新系统和安装依赖 (Debian/Ubuntu)..."
            apt-get update
            # 添加必要的系统工具包
            apt-get install -y sudo screen unzip wget curl uuid-runtime jq supervisor procps iproute2 iputils-ping net-tools
            
            # 确保 supervisor 服务停止
            if [ -f "/var/run/supervisor.sock" ]; then
                rm -f /var/run/supervisor.sock
            fi
            if [ -f "/var/run/supervisord.pid" ]; then
                kill -9 $(cat /var/run/supervisord.pid) 2>/dev/null
                rm -f /var/run/supervisord.pid
            fi
            
            # 初始化 supervisor 配置
            mkdir -p /etc/supervisor/conf.d
            mkdir -p /var/log/supervisor
            
            if [ ! -f "/etc/supervisor/supervisord.conf" ]; then
                echo "创建 supervisor 默认配置..."
                cat > /etc/supervisor/supervisord.conf <<EOF
[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700

[supervisord]
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
nodaemon=false

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///var/run/supervisor.sock

[include]
files = /etc/supervisor/conf.d/*.conf
EOF
            fi
            ;;
        CentOS)
            echo "更新系统和安装依赖 (CentOS)..."
            yum update -y
            yum install -y sudo screen unzip wget curl util-linux jq supervisor
            ;;
        Alpine)
            echo "更新系统和安装依赖 (Alpine)..."
            apk update
            apk add --no-cache sudo screen unzip wget curl util-linux jq bash supervisor
            
            # 初始化 supervisor 配置
            mkdir -p /etc/supervisor/conf.d
            mkdir -p /var/log/supervisor
            
            if [ ! -f "/etc/supervisord.conf" ]; then
                echo "创建 supervisor 默认配置..."
                cat > /etc/supervisord.conf <<EOF
[unix_http_server]
file=/run/supervisord.sock

[supervisord]
logfile=/var/log/supervisor/supervisord.log
pidfile=/run/supervisord.pid
childlogdir=/var/log/supervisor

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///run/supervisord.sock

[include]
files = /etc/supervisor/conf.d/*.conf
EOF
            fi
            
            # 确保 supervisor 服务正在运行
            if ! pgrep supervisord >/dev/null; then
                echo "启动 supervisord..."
                supervisord -c /etc/supervisord.conf
            fi
            ;;
        *)
            echo "不支持的操作系统"
            return 1
            ;;
    esac
}

# 添加一个安全的下载函数，带有重试机制
download_with_retry() {
    url="$1"
    output="$2"
    max_retries=3
    retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        if [ -n "$output" ]; then
            if curl -L --fail --silent --show-error "$url" -o "$output"; then
                return 0
            fi
        else
            if curl -L --fail --silent --show-error "$url"; then
                return 0
            fi
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $max_retries ]; then
            echo "下载失败，${retry_count}秒后重试..."
            sleep $retry_count
        fi
    done
    
    echo "下载失败: $url"
    return 1
}

# 添加新的下载函数实现
download_file() {
    url="$1"
    output_file="$2"
    
    # 验证URL
    if [ -z "$url" ] || [ "${url#http}" = "$url" ]; then
        echo "无效的URL: $url"
        return 1
    fi
    
    # 创建临时目录
    tmp_dir=$(mktemp -d)
    if [ ! -d "$tmp_dir" ]; then
        echo "无法创建临时目录"
        return 1
    fi
    
    # 下载文件，增加重试和超时设置
    if [ -n "$output_file" ]; then
        if ! curl -L --retry 3 --retry-delay 2 --connect-timeout 10 -m 30 \
            --fail --silent --show-error "$url" -o "$tmp_dir/$(basename "$output_file")"; then
            rm -rf "$tmp_dir"
            return 1
        fi
        # 确保目标目录存在
        mkdir -p "$(dirname "$output_file")"
        mv "$tmp_dir/$(basename "$output_file")" "$output_file"
    else
        if ! curl -L --retry 3 --retry-delay 2 --connect-timeout 10 -m 30 \
            --fail --silent --show-error "$url"; then
            rm -rf "$tmp_dir"
            return 1
        fi
    fi
    
    rm -rf "$tmp_dir"
    return 0
}

# 获取版本、下载和解压文件
get_version_and_download() {
    # 获取系统信息
    kernel_version=$(uname -r)
    arch=$(uname -m)
    echo "系统架构: $arch, 内核版本: $kernel_version"

    # 判断内核版本是否满足使用 io-uring 的条件
    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)
    can_use_io=$([ "$compare_kernel_version" = "5.10" ] && [ "$kernel_version" != "5.10" ] && echo true || echo false)

    read -p "是否使用默认下载地址？[Y/n]: " use_default
    use_default=$(echo "$use_default" | tr '[:upper:]' '[:lower:]')

    if [ "$use_default" = "n" ] || [ "$use_default" = "no" ]; then
        echo "请输入自定义的下载地址:"
        read download_url
    else
        # 获取版本信息并进行净化处理
        latest_version=$(curl -s "https://api.github.com/repos/liulilittle/openppp2/releases/latest" | tr -d '\000-\031' | jq -r '.tag_name // empty')
        if [ -z "$latest_version" ]; then
            echo "无法获取最新版本信息"
            return 1
        fi
        echo "当前最新版本: $latest_version"
        
        read -p "请输入要下载的版本号(回车默认使用最新版本 $latest_version): " version
        version=${version:-$latest_version}

        # 根据架构设定候选资产名称
        if [ "$arch" = "x86_64" ]; then
            asset1="openppp2-linux-amd64-io-uring.zip"
            asset2="openppp2-linux-amd64.zip"
        elif [ "$arch" = "aarch64" ]; then
            asset1="openppp2-linux-aarch64-io-uring.zip"
            asset2="openppp2-linux-aarch64.zip"
        elif [ "$arch" = "armv7l" ]; then
            asset1="openppp2-linux-armv7l.zip"
        else
            echo "不支持的架构: $arch"
            exit 1
        fi

        # 获取并净化发布信息
        if [ "$version" = "$latest_version" ]; then
            release_info=$(curl -s "https://api.github.com/repos/liulilittle/openppp2/releases/latest" )
        else
            release_info=$(curl -s "https://api.github.com/repos/liulilittle/openppp2/releases/tags/$version" )
        fi
        echo "$release_info"
        if ! echo "$release_info" | jq empty 2>/dev/null; then
            echo "获取的发布信息格式无效"
            return 1
        fi

        [ -z "$release_info" ] && { echo "获取版本 $version 的发布信息失败,请检查版本号是否正确."; return 1; }

        # 查找可用的下载链接并验证 JSON 响应
        selected_asset=""
        download_url=$(echo "$release_info" | jq -r --arg name "$asset1" '.assets[] | select(.name == $name) | .browser_download_url // empty')
        if [ -n "$download_url" ] && [ "$download_url" != "null" ]; then
            selected_asset="$asset1"
        else
            download_url=$(echo "$release_info" | jq -r --arg name "$asset2" '.assets[] | select(.name == $name) | .browser_download_url // empty')
            if [ -n "$download_url" ] && [ "$download_url" != "null" ]; then
                selected_asset="$asset2"
            fi
        fi

        # 验证下载 URL
        if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
            echo "无法获取有效的下载链接"
            return 1
        fi

        # 内核版本检查与版本选择
        if [ "$selected_asset" = "$asset1" ] && [ "$can_use_io" = "true" ]; then
            echo "检测到当前内核版本支持 io_uring 特性(要求 5.10+)"
            read -p "是否要使用 io_uring 优化版本？[Y/n] " use_io
            use_io=$(echo "$use_io" | tr '[:upper:]' '[:lower:]')
            if [ "$use_io" = "n" ] || [ "$use_io" = "no" ]; then
                selected_asset="$asset2"
                download_url=$(echo "$release_info" | jq -r --arg name "$asset2" '.assets[] | select(.name == $name) | .browser_download_url')
            fi
        elif [ "$can_use_io" = "false" ]; then
            echo "当前内核版本不满足 io_uring 要求(需要 5.10+),自动选择标准版本"
            selected_asset="$asset2"
            download_url=$(echo "$release_info" | jq -r --arg name "$asset2" '.assets[] | select(.name == $name) | .browser_download_url')
        fi

        [ -z "$selected_asset" ] && { echo "无法获取到构建文件的下载链接."; exit 1; }
        echo "选择的构建文件: $selected_asset"
    fi

    # 统一处理下载和解压
    echo "下载文件中..."
    if ! download_file "$download_url" "ppp.zip"; then
        echo "下载失败，请检查网络连接或URL是否正确"
        return 1
    fi
    
    if [ ! -f "ppp.zip" ]; then
        echo "下载文件未找到"
        return 1
    fi
    
    echo "解压下载的文件..."
    if ! unzip -o ppp.zip -x 'appsettings.json'; then
        echo "解压失败"
        rm -f ppp.zip
        return 1
    fi
    rm -f ppp.zip
    chmod +x ppp

    return 0
}

# 配置supervisor服务
configure_service() {
    mode_choice=$1
    command=""

    if [ "$mode_choice" = "2" ]; then
        command='/usr/bin/screen -DmS ppp '"$ppp_dir"'/ppp --mode=client --tun-host=yes --tun-ssmt=4/mq --tun-flash=yes --tun-mux=0 --tun-static=yes'
    else
        command='/usr/bin/screen -DmS ppp '"$ppp_dir"'/ppp --mode=server'
    fi

    echo "配置supervisor服务..."
    
    # 确保目录存在
    mkdir -p /etc/supervisor/conf.d
    mkdir -p /var/log
    
    # 创建日志文件
    touch /var/log/ppp.err.log
    touch /var/log/ppp.out.log
    
    cat > /etc/supervisor/conf.d/ppp.conf <<EOF
[program:ppp]
command=$command
directory=$ppp_dir
autostart=true
autorestart=$([ "$mode_choice" = "2" ] && echo "false" || echo "true")
stderr_logfile=/var/log/ppp.err.log
stdout_logfile=/var/log/ppp.out.log
user=root
startsecs=0
stopwaitsecs=0
EOF

    # 检查并启动 supervisor
    if ! command -v supervisord >/dev/null 2>&1; then
        echo "supervisord 未安装，重新安装依赖..."
        install_dependencies
    fi

    # 确保旧的 supervisor sock 和 pid 文件被清理
    if [ -f "/var/run/supervisor.sock" ]; then
        rm -f /var/run/supervisor.sock
    fi
    if [ -f "/var/run/supervisord.pid" ]; then
        kill -9 $(cat /var/run/supervisord.pid) 2>/dev/null
        rm -f /var/run/supervisord.pid
    fi
    
    # 检查是否有其他 supervisord 进程
    if pgrep supervisord >/dev/null 2>&1; then
        echo "发现正在运行的 supervisord 进程，尝试停止..."
        pkill supervisord
        sleep 2
    fi

    # 启动 supervisord
    echo "启动 supervisord..."
    supervisord -c /etc/supervisor/supervisord.conf

    # 等待 supervisor 启动
    sleep 2
    if ! supervisorctl status >/dev/null 2>&1; then
        echo "supervisord 启动失败"
        return 1
    fi

    # 重新加载supervisor配置
    supervisorctl reread
    supervisorctl update
}

# 安装PPP服务
install_ppp() {
    install_dependencies || return 1

    echo "创建目录并进入..."
    mkdir -p $ppp_dir
    cd $ppp_dir

    get_version_and_download

    echo "请选择模式(默认为服务端):"
    echo "1) 服务端"
    echo "2) 客户端"
    read -p "输入选择 (1 或 2,默认为服务端): " mode_choice
    mode_choice=${mode_choice:-1}

    configure_service "$mode_choice"
    modify_config
    start_ppp
    echo "PPP服务已配置并启动."
    show_menu
}

# 卸载PPP服务
uninstall_ppp() {
    echo "停止并卸载PPP服务..."
    supervisorctl stop ppp
    rm -f /etc/supervisor/conf.d/ppp.conf
    supervisorctl reread
    supervisorctl update
    echo "删除安装文件..."

    pids=$(pgrep ppp)
    if [ -z "$pids" ]; then
        echo "没有找到PPP进程."
    else
        echo "找到PPP进程,正在杀死..."
        kill $pids
        echo "已发送终止信号到PPP进程."
    fi

    sudo rm -rf $ppp_dir
    echo "PPP服务已完全卸载."
}

# 启动PPP服务
start_ppp() {
    supervisorctl start ppp
    echo "PPP服务已启动."
}

# 停止PPP服务
stop_ppp() {
    supervisorctl stop ppp
    echo "PPP服务已停止."
}

# 重启PPP服务
restart_ppp() {
    supervisorctl restart ppp
    echo "PPP服务已重启."
}

# 重新配置ppp系统服务文件
reconfigure_ppp() {
    echo "重新配置PPP服务..."
    stop_ppp
    echo "请选择模式(默认为服务端):"
    echo "1) 服务端"
    echo "2) 客户端"
    read -p "输入选择 (1 或 2,默认为服务端): " mode_choice
    mode_choice=${mode_choice:-1}

    configure_service "$mode_choice"
    start_ppp
    echo "PPP系统服务已重新配置并启动."
}

# 更新PPP服务
update_ppp() {
    echo "更新PPP服务中..."
    cd $ppp_dir
    get_version_and_download
    
    echo "正在停止旧服务以替换文件..."
    stop_ppp
    
    echo "启动更新后的PPP服务..."
    restart_ppp
    echo "PPP服务已更新并重启."
}

# 查看PPP会话
view_ppp_session() {
    echo "查看PPP会话..."
    screen -r ppp
    echo "提示:使用 'Ctrl+a d' 来detach会话而不是关闭它."
}

# 查看当前配置
view_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    if [ ! -f "${ppp_config}" ]; then
        echo "配置文件不存在"
        return 1
    fi
    
    echo -e "\n当前配置文件内容:"
    jq . "${ppp_config}"
}

# 编辑特定配置项
edit_config_item() {
    ppp_config="${ppp_dir}/appsettings.json"
    if [ ! -f "${ppp_config}" ]; then
        echo "配置文件不存在"
        return 1
    fi
    
    view_config
    
    echo -e "\n可配置项:"
    echo "1) 接口IP"
    echo "2) 公网IP"
    echo "3) 监听端口"
    echo "4) 并发数"
    echo "5) 客户端GUID"
    
    read -p "请选择要修改的配置项 (1-5): " choice
    
    case $choice in
        1)
            read -p "请输入新的接口IP: " new_value
            jq ".ip.interface = \"${new_value}\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        2)
            read -p "请输入新的公网IP: " new_value
            jq ".ip.public = \"${new_value}\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        3)
            read -p "请输入新的监听端口: " new_value
            jq ".tcp.listen.port = ${new_value} | .udp.listen.port = ${new_value}" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        4)
            read -p "请输入新的并发数: " new_value
            jq ".concurrent = ${new_value}" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        5)
            read -p "请输入新的客户端GUID: " new_value
            jq ".client.guid = \"${new_value}\"" "${ppp_config}" > tmp.json && mv tmp.json "${ppp_config}"
            ;;
        *)
            echo "无效选择"
            return 1
            ;;
    esac
    
    echo "配置项已更新"
    restart_ppp
}

# 修改PPP配置文件
modify_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    
    # 备份原配置文件
    if [ -f "${ppp_config}" ];then
        backup_file="${ppp_config}.$(date +%Y%m%d%H%M%S).bak"
        cp "${ppp_config}" "${backup_file}"
        echo "已备份原配置文件到 ${backup_file}"
    fi
    
    if [ ! -f "${ppp_config}" ]; then
        echo "下载默认配置文件..."
        if ! download_file "https://raw.githubusercontent.com/liulilittle/openppp2/main/appsettings.json" "${ppp_config}"; then
            echo "下载配置文件失败，请检查网络连接"
            return 1
        fi
    fi
    
    echo -e "\n当前节点信息:"
    echo "接口IP: $(jq -r '.ip.interface' ${ppp_config})"
    echo "公网IP: $(jq -r '.ip.public' ${ppp_config})"
    echo "监听端口: $(jq -r '.tcp.listen.port' ${ppp_config})"
    echo "并发数: $(jq -r '.concurrent' ${ppp_config})"
    echo "客户端GUID: $(jq -r '.client.guid' ${ppp_config})"

    echo "检测网络信息..."
    # 添加错误处理的网络检测
    if command -v curl >/dev/null 2>&1; then
        public_ip=$(curl -m 10 -s ip.sb || curl -m 10 -s ifconfig.me || echo "::")
    else
        public_ip="::"
    fi
    
    if command -v ip >/dev/null 2>&1; then
        local_ips=$(ip -4 addr show | grep 'inet ' | grep -v ' lo' | awk '{print $2}' | cut -d/ -f1 | tr '\n' ' ')
    elif command -v ifconfig >/dev/null 2>&1; then
        local_ips=$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | tr '\n' ' ')
    else
        local_ips="无法获取本地IP"
    fi
    
    echo -e "检测到的公网IP: ${public_ip}\n本地IP地址: ${local_ips}"

    default_public_ip="::"
    read -p "请输入服务器端 IP地址(服务端默认为${default_public_ip},客户端则写服务器端的IP地址): " public_ip
    public_ip=${public_ip:-$default_public_ip}

    while true; do
        read -p "请输入服务器端 端口 [默认: 2025]: " listen_port
        listen_port=${listen_port:-2025}
    
        if [ "$listen_port" -ge 1 ] && [ "$listen_port" -le 65535 ]; then
            break
        else
            echo "输入的端口无效.请确保它是在1到65535的范围内."
        fi
    done

    default_interface_ip="::"
    read -p "请输入内网IP地址(服务端默认为${default_interface_ip},客户端可写内网IP地址): " interface_ip
    interface_ip=${interface_ip:-$default_interface_ip}

    concurrent=$(nproc)
    if command -v uuidgen >/dev/null 2>&1; then
        client_guid=$(uuidgen)
    else
        client_guid=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
    fi

    echo -e "\n正在更新配置文件..."
    tmp_file=$(mktemp)
    
    update_json() {
        _key=$1
        _value=$2
        _type=$3
        
        case "$_type" in
            array)
                jq --argjson val "$_value" "$_key = \$val" "${ppp_config}" > "${tmp_file}"
                ;;
            number|boolean)
                jq "$_key = $_value" "${ppp_config}" > "${tmp_file}"
                ;;
            *)
                jq "$_key = \"$_value\"" "${ppp_config}" > "${tmp_file}"
                ;;
        esac
        
        if [ $? -eq 0 ]; then
            mv "${tmp_file}" "${ppp_config}"
        else
            echo "修改配置项 $_key 失败"
            rm -f "${tmp_file}"
            exit 1
        fi
    }

    update_json ".concurrent" "${concurrent}" "number"
    update_json ".cdn" "[]" "array"
    update_json ".ip.public" "${public_ip}" "string"
    update_json ".ip.interface" "${interface_ip}" "string"
    update_json ".vmem.size" "0" "number"
    update_json ".tcp.listen.port" "${listen_port}" "number"
    update_json ".udp.listen.port" "${listen_port}" "number"
    update_json ".udp.static.\"keep-alived\"" "[1,10]" "array"
    update_json ".udp.static.aggligator" "0" "number"
    update_json ".udp.static.servers" "[\"${public_ip}:${listen_port}\"]" "array"
    update_json ".websocket.host" "ppp2" "string"
    update_json ".websocket.path" "/tun" "string"
    update_json ".websocket.listen.ws" "2095" "number"
    update_json ".websocket.listen.wss" "2096" "number"
    update_json ".server.log" "/dev/null" "string"
    update_json ".server.mapping" "true" "boolean"
    update_json ".server.backend" "" "string"
    update_json ".client.guid" "{${client_guid}}" "string"
    update_json ".client.server" "ppp://${public_ip}:${listen_port}/" "string"
    update_json ".client.bandwidth" "0" "number"
    update_json ".client.\"server-proxy\"" "" "string"
    update_json ".client.\"http-proxy\".bind" "0.0.0.0" "string"
    update_json ".client.\"http-proxy\".port" "${listen_port}" "number"
    update_json ".client.\"socks-proxy\".bind" "::" "string"
    update_json ".client.\"socks-proxy\".port" "$((listen_port + 1))" "number"
    update_json ".client.\"socks-proxy\".username" "admin" "string"
    update_json ".client.\"socks-proxy\".password" "password" "string"

    echo "配置文件更新完成."

    echo -e "\n修改后的配置参数:"
    echo "接口IP: $(jq -r '.ip.interface' ${ppp_config})"
    echo "公网IP: $(jq -r '.ip.public' ${ppp_config})"
    echo "监听端口: $(jq -r '.tcp.listen.port' ${ppp_config})"
    echo "并发数: $(jq -r '.concurrent' ${ppp_config})"
    echo "客户端GUID: $(jq -r '.client.guid' ${ppp_config})"
    echo -e "\n${ppp_config} 服务端配置文件修改成功."
    echo -e "\n${ppp_config} 同时可以当作客户端配置文件."
    restart_ppp
}

# 显示主菜单
show_menu() {
    PS3='请选择一个操作: '
    echo "1) 安装PPP"
    echo "2) 启动PPP"
    echo "3) 停止PPP"
    echo "4) 重启PPP"
    echo "5) 更新PPP"
    echo "6) 卸载PPP"
    echo "7) 查看PPP会话"
    echo "8) 查看配置"
    echo "9) 编辑配置项"
    echo "10) 修改配置文件"
    echo "11) 重新配置ppp系统服务"
    echo "12) 退出"
    
    read -p "请选择操作 (1-12): " choice
    case $choice in
        1) install_ppp ;;
        2) start_ppp ;;
        3) stop_ppp ;;
        4) restart_ppp ;;
        5) update_ppp ;;
        6) uninstall_ppp ;;
        7) view_ppp_session ;;
        8) view_config ;;
        9) edit_config_item ;;
        10) modify_config ;;
        11) reconfigure_ppp ;;
        12) return 0 ;;
        *) echo "无效选项" ;;
    esac
    show_menu
}

# 脚本入口
show_menu
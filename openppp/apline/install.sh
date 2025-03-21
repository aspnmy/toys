#!/bin/bash

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
function install_dependencies() {
    echo "检测到操作系统:$OS"
    
    case "$OS" in
        ubuntu | debian)
            echo "更新系统和安装依赖 (Debian/Ubuntu)..."
            apt update && apt install -y sudo screen unzip wget curl uuid-runtime jq
            ;;
        CentOS)
            echo "更新系统和安装依赖 (CentOS)..."
            yum update -y
            yum install -y sudo screen unzip wget curl util-linux jq
            ;;
        Alpine)
            echo "更新系统和安装依赖 (Alpine)..."
            apk update
            apk add --no-cache sudo screen unzip wget curl util-linux jq bash
            ;;
        *)
            echo "不支持的操作系统"
            return 1
            ;;
    esac
}

# 获取版本、下载和解压文件
function get_version_and_download() {
    # 获取系统信息
    kernel_version=$(uname -r)
    arch=$(uname -m)
    echo "系统架构: $arch, 内核版本: $kernel_version"

    # 判断内核版本是否满足使用 io-uring 的条件
    compare_kernel_version=$(echo -e "5.10\n$kernel_version" | sort -V | head -n1)
    can_use_io=$([[ "$compare_kernel_version" == "5.10" && "$kernel_version" != "5.10" ]] && echo true || echo false)

    latest_version=$(curl -s https://api.github.com/repos/rebecca554owen/toys/releases/latest | jq -r '.tag_name')
    version=$latest_version

    if [[ "$arch" == "x86_64" ]]; then
        assets=("openppp2-linux-amd64-io-uring.zip" "openppp2-linux-amd64.zip")
    elif [[ "$arch" == "aarch64" ]]; then
        assets=("openppp2-linux-aarch64-io-uring.zip" "openppp2-linux-aarch64.zip")
    else
        echo "不支持的架构: $arch"
        exit 1
    fi

    release_info=$(curl -s https://api.github.com/repos/rebecca554owen/toys/releases/latest)
    [[ -z "$release_info" ]] && { echo "获取版本信息失败"; exit 1; }

    selected_asset=""
    for asset in "${assets[@]}"; do
        download_url=$(echo "$release_info" | jq -r --arg name "$asset" '.assets[] | select(.name == $name) | .browser_download_url')
        [[ -n "$download_url" && "$download_url" != "null" ]] && { selected_asset=$asset; break; }
    done

    if [[ "$can_use_io" == false ]]; then
        selected_asset="${assets[1]}"
    fi

    [[ -z "$selected_asset" ]] && { echo "无法获取下载链接"; exit 1; }
    echo "选择的构建文件: $selected_asset"

    wget "$download_url"
    unzip -o '*.zip' -x 'appsettings.json' && rm *.zip
    chmod +x ppp
}

# 配置系统服务
function configure_service() {
    local mode_choice=$1
    local exec_start
    local restart_policy

    if [[ "$mode_choice" == "2" ]]; then
    #/usr/bin/screen -DmS ppp /etc/ppp/ppp --mode=client --tun-host=no --tun-ssmt=4/mq --tun-flash=yes --tun-mux=0
        exec_start='/usr/bin/screen -DmS ppp '"$ppp_dir"'/ppp --mode=client --tun-host=yes --tun-ssmt=4/mq --tun-flash=yes --tun-mux=0'
        restart_policy="no"
    else
        exec_start='/usr/bin/screen -DmS ppp '"$ppp_dir"'/ppp --mode=server'
        restart_policy="always"
    fi

    echo "配置系统服务..."
    cat > /etc/systemd/system/ppp.service <<'EOF'
[Unit]
Description=PPP Service with Screen
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${ppp_dir}
ExecStart=${exec_start}
Restart=${restart_policy}
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    # 替换变量
    sed -i "s|\${ppp_dir}|$ppp_dir|g" /etc/systemd/system/ppp.service
    sed -i "s|\${exec_start}|$exec_start|g" /etc/systemd/system/ppp.service
    sed -i "s|\${restart_policy}|$restart_policy|g" /etc/systemd/system/ppp.service
}

# 安装PPP服务
function install_ppp() {
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
function uninstall_ppp() {
    echo "停止并卸载PPP服务..."
    sudo systemctl stop ppp.service
    sudo systemctl disable ppp.service
    sudo rm -f /etc/systemd/system/ppp.service
    sudo systemctl daemon-reload
    sudo systemctl reset-failed
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
function start_ppp() {
    sudo systemctl enable ppp.service
    sudo systemctl daemon-reload
    sudo systemctl start ppp.service
    echo "PPP服务已启动."
}

# 停止PPP服务
function stop_ppp() {
    sudo systemctl stop ppp.service
    echo "PPP服务已停止."
}

# 重启PPP服务
function restart_ppp() {
    sudo systemctl daemon-reload
    sudo systemctl restart ppp.service
    echo "PPP服务已重启."
}

# 重新配置ppp系统服务文件
function reconfigure_ppp() {
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
function update_ppp() {
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
function view_ppp_session() {
    echo "查看PPP会话..."
    screen -r ppp
    echo "提示:使用 'Ctrl+a d' 来detach会话而不是关闭它."
}

# 查看当前配置
function view_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    if [ ! -f "${ppp_config}" ]; then
        echo "配置文件不存在"
        return 1
    fi
    
    echo -e "\n当前配置文件内容:"
    jq . "${ppp_config}"
}

# 编辑特定配置项
function edit_config_item() {
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
function modify_config() {
    ppp_config="${ppp_dir}/appsettings.json"
    
    # 备份原配置文件
    if [ -f "${ppp_config}" ]; then
        backup_file="${ppp_config}.$(date +%Y%m%d%H%M%S).bak"
        cp "${ppp_config}" "${backup_file}"
        echo "已备份原配置文件到 ${backup_file}"
    fi
    
    if [ ! -f "${ppp_config}" ]; then
        echo "下载默认配置文件..."
        if ! curl -sSL  "https://raw.githubusercontent.com/liulilittle/openppp2/main/appsettings.json" -o "${ppp_config}"; then
            echo "下载配置文件失败,请检查网络连接"
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
    public_ip=$(curl -m 10 -s ip.sb || echo "::")
    local_ips=$(ip addr | grep 'inet ' | grep -v ' lo' | awk '{print $2}' | cut -d/ -f1 | tr '\n' ' ')
    echo -e "检测到的公网IP: ${public_ip}\n本地IP地址: ${local_ips}"

    default_public_ip="::"
    read -p "请输入服务器端 IP地址(服务端默认为${default_public_ip},客户端则写服务器端的IP地址): " public_ip
    public_ip=${public_ip:-$default_public_ip}

    while true; do
        read -p "请输入服务器端 端口 [默认: 2025]: " listen_port
        listen_port=${listen_port:-2025}
    
        if [[ "$listen_port" =~ ^[0-9]+$ ]] && [ "$listen_port" -ge 1 ] && [ "$listen_port" -le 65535 ]; then
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

    declare -A config_changes=(
        [".concurrent"]=${concurrent}
        [".cdn"]="[]"
        [".ip.public"]="${public_ip}"
        [".ip.interface"]="${interface_ip}"
        [".vmem.size"]=0
        [".tcp.listen.port"]=${listen_port}
        [".udp.listen.port"]=${listen_port}
        [".udp.static.\"keep-alived\""]="[1,10]"
        [".udp.static.aggligator"]=0
        [".udp.static.servers"]="[\"${public_ip}:${listen_port}\"]"
        [".websocket.host"]="ppp2"
        [".websocket.path"]="/tun"
        [".websocket.listen.ws"]=2095
        [".websocket.listen.wss"]=2096
        [".server.log"]="/dev/null"
        [".server.mapping"]=true
        [".server.backend"]=""
        [".server.mapping"]=true
        [".client.guid"]="{${client_guid}}"
        [".client.server"]="ppp://${public_ip}:${listen_port}/"
        [".client.bandwidth"]=0
        [".client.\"server-proxy\""]=""
        [".client.\"http-proxy\".bind"]="0.0.0.0"
        [".client.\"http-proxy\".port"]=${listen_port}
        [".client.\"socks-proxy\".bind"]="::"
        [".client.\"socks-proxy\".port"]=$((listen_port + 1))
        [".client.\"socks-proxy\".username"]="admin"
        [".client.\"socks-proxy\".password"]="password"
    )

    echo -e "\n正在更新配置文件..."
    tmp_file=$(mktemp)

    for key in "${!config_changes[@]}"; do
        value=${config_changes[$key]}
        if [[ $value =~ ^\[.*\]$ ]]; then
            if ! jq --argjson val "${value}" "${key} = \$val" "${ppp_config}" > "${tmp_file}" 2>/dev/null; then
                echo "修改配置项 ${key} 失败"
                rm -f "${tmp_file}"
                exit 1
            fi
        elif [[ $value =~ ^[0-9]+$ ]] || [[ $value == "true" ]] || [[ $value == "false" ]]; then
            if ! jq "${key} = ${value}" "${ppp_config}" > "${tmp_file}" 2>/dev/null; then
                echo "修改配置项 ${key} 失败"
                rm -f "${tmp_file}"
                exit 1
            fi
        else
            if ! jq "${key} = \"${value}\"" "${ppp_config}" > "${tmp_file}" 2>/dev/null; then
                echo "修改配置项 ${key} 失败"
                rm -f "${tmp_file}"
                exit 1
            fi
        fi
        mv "${tmp_file}" "${ppp_config}"
    done

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

# 显示使用帮助
function show_usage() {
    echo "用法: $0 <命令> [参数]"
    echo "命令:"
    echo "  install [mode]     - 安装PPP (mode: 1=服务端, 2=客户端)"
    echo "  start             - 启动PPP"
    echo "  stop              - 停止PPP"
    echo "  restart           - 重启PPP"
    echo "  update            - 更新PPP"
    echo "  uninstall         - 卸载PPP"
    echo "  view-session      - 查看PPP会话"
    echo "  view-config       - 查看配置"
    echo "  edit-config <项目> <值> - 编辑配置项"
    echo "  modify-config <公网IP> <端口> <内网IP>  - 修改配置文件"
    echo "  reconfigure <mode> - 重新配置PPP系统服务 (mode: 1=服务端, 2=客户端)"
    exit 1
}

# 替换show_menu函数为命令行参数处理
if [ $# -eq 0 ]; then
    show_usage
fi

command=$1
shift

case "$command" in
    "install")
        mode=${1:-1}
        install_dependencies
        cd $ppp_dir
        get_version_and_download
        configure_service "$mode"
        modify_config ${@:2}
        start_ppp
        ;;
    "start")
        start_ppp
        ;;
    "stop")
        stop_ppp
        ;;
    "restart")
        restart_ppp
        ;;
    "update")
        update_ppp
        ;;
    "uninstall")
        uninstall_ppp
        ;;
    "view-session")
        view_ppp_session
        ;;
    "view-config")
        view_config
        ;;
    "edit-config")
        [ $# -lt 2 ] && show_usage
        item=$1
        value=$2
        edit_config_item "$item" "$value"
        ;;
    "modify-config")
        [ $# -lt 3 ] && show_usage
        modify_config "$@"
        ;;
    "reconfigure")
        mode=${1:-1}
        reconfigure_ppp "$mode"
        ;;
    *)
        show_usage
        ;;
esac
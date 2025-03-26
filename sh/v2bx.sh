#!/bin/bash

# 设置颜色变量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 无颜色

# 定义v2bx变量
v2bx_config="/etc/V2bX/config.json"

# 默认配置
DEFAULT_LOG_LEVEL="info"
DEFAULT_API_HOST="https://api.example.com"
DEFAULT_API_KEY="your_api_key"
DEFAULT_NODE_ID="1"
DEFAULT_CORE_TYPE="xray"
DEFAULT_NODE_TYPE="vless"
DEFAULT_CERT_MODE="none"
DEFAULT_CERT_DOMAIN="node.example.com"
DEFAULT_CF_API_EMAIL=""
DEFAULT_CF_API_KEY=""

# 加载配置
load_config() {
    declare -gA config
    if [ -f "$v2bx_config" ]; then
        local json_content=$(<"$v2bx_config")
        echo -e "${GREEN}正在加载配置文件，请耐心等待...${NC}"
        # 使用jq一次性提取所有配置项
        local parsed_config=$(jq -r '{
            LogLevel: .Log.Level,
            ApiHost: .Nodes[0].ApiHost,
            ApiKey: .Nodes[0].ApiKey,
            NodeID: .Nodes[0].NodeID,
            CoreType: .Nodes[0].Core,
            NodeType: .Nodes[0].NodeType,
            CertMode: .Nodes[0].CertConfig.CertMode,
            CertDomain: .Nodes[0].CertConfig.CertDomain,
            CF_API_EMAIL: .Nodes[0].CertConfig.DNSEnv.CF_API_EMAIL,
            CF_API_KEY: .Nodes[0].CertConfig.DNSEnv.CF_API_KEY
        } | to_entries[] | "\(.key)=\(.value)"' <<<"$json_content" 2>/dev/null)
        # 解析成功时处理结果，失败时使用默认值
        if [ $? -eq 0 ]; then
            declare -A default_config=(
                [LogLevel]="$DEFAULT_LOG_LEVEL"
                [ApiHost]="$DEFAULT_API_HOST"
                [ApiKey]="$DEFAULT_API_KEY"
                [NodeID]="$DEFAULT_NODE_ID"
                [CoreType]="$DEFAULT_CORE_TYPE"
                [NodeType]="$DEFAULT_NODE_TYPE"
                [CertMode]="$DEFAULT_CERT_MODE"
                [CertDomain]="$DEFAULT_CERT_DOMAIN"
                [CF_API_EMAIL]="$DEFAULT_CF_API_EMAIL"
                [CF_API_KEY]="$DEFAULT_CF_API_KEY"
            )
            # 遍历解析结果并赋值给config数组
            while IFS='=' read -r key value; do
                [ -n "$value" ] && config["$key"]="$value" || config["$key"]="${default_config[$key]}"
            done <<<"$parsed_config"
        else
            echo -e "${RED}配置文件解析失败，使用默认配置${NC}"
            config=(
                [LogLevel]="$DEFAULT_LOG_LEVEL"
                [ApiHost]="$DEFAULT_API_HOST"
                [ApiKey]="$DEFAULT_API_KEY"
                [NodeID]="$DEFAULT_NODE_ID"
                [CoreType]="$DEFAULT_CORE_TYPE"
                [NodeType]="$DEFAULT_NODE_TYPE"
                [CertMode]="$DEFAULT_CERT_MODE"
                [CertDomain]="$DEFAULT_CERT_DOMAIN"
                [CF_API_EMAIL]="$DEFAULT_CF_API_EMAIL"
                [CF_API_KEY]="$DEFAULT_CF_API_KEY"
            )
        fi
    else
        echo -e "${RED}配置文件不存在，使用默认配置${NC}"
        config["LogLevel"]="$DEFAULT_LOG_LEVEL"
        config["ApiHost"]="$DEFAULT_API_HOST"
        config["ApiKey"]="$DEFAULT_API_KEY"
        config["NodeID"]="$DEFAULT_NODE_ID"
        config["CoreType"]="$DEFAULT_CORE_TYPE"
        config["NodeType"]="$DEFAULT_NODE_TYPE"
        config["CertMode"]="$DEFAULT_CERT_MODE"
        config["CertDomain"]="$DEFAULT_CERT_DOMAIN"
        config["CF_API_EMAIL"]="$DEFAULT_CF_API_EMAIL"
        config["CF_API_KEY"]="$DEFAULT_CF_API_KEY"
    fi
    # 将配置变量导出到全局环境
    for key in "${!config[@]}"; do
        export "$key"="${config[$key]}"
    done
}

# 配置显示函数
display_config() {
    load_config  # 加载配置
    echo -e "${GREEN}配置信息如下：${NC}"
    echo -e "LogLevel:       ${config[LogLevel]}"
    echo -e "ApiHost:        ${config[ApiHost]}"
    echo -e "ApiKey:         ${config[ApiKey]}"
    echo -e "NodeID:         ${config[NodeID]}"
    echo -e "CoreType:       ${config[CoreType]}"
    echo -e "NodeType:       ${config[NodeType]}"
    echo -e "CertMode:       ${config[CertMode]}"
    echo -e "CertDomain:     ${config[CertDomain]}"
    echo -e "CF_API_EMAIL:   ${config[CF_API_EMAIL]}"
    echo -e "CF_API_KEY:     ${config[CF_API_KEY]}"
}

# 检查必须的配置变量
check_required_env() {
    missing_vars=""
    # NodeID 为必要参数
    if [ -z "$NodeID" ]; then
        missing_vars="$missing_vars NodeID"
    fi
    if [ -n "$missing_vars" ]; then
        echo -e "${RED}错误：缺少必要的变量：$missing_vars${NC}"
        return 1
    fi
    return 0
}

# 验证核心类型和节点类型兼容性
validate_core_node_types() {
    case "$CoreType" in
        "xray")
            core_xray=true
            case "$NodeType" in
                "vless" | "vmess" | "shadowsocks" | "trojan")
                    ;;
                *)
                    echo -e "${RED}错误：xray核心不支持该协议：$NodeType${NC}"
                    echo -e "${YELLOW}xray核心支持的协议：vless, vmess, shadowsocks, trojan${NC}"
                    return 1
                    ;;
            esac
            ;;
        "sing")
            core_sing=true
            case "$NodeType" in
                "vless" | "vmess" | "shadowsocks" | "trojan" | "hysteria" | "hysteria2")
                    ;;
                *)
                    echo -e "${RED}错误：sing-box核心不支持该协议：$NodeType${NC}"
                    echo -e "${YELLOW}sing-box核心支持的协议：vless, vmess, shadowsocks, trojan, hysteria, hysteria2${NC}"
                    return 1
                    ;;
            esac
            ;;
        "hysteria2")
            core_hysteria2=true
            if [ "$NodeType" != "hysteria2" ]; then
                echo -e "${RED}错误：hysteria2核心仅支持hysteria2协议${NC}"
                return 1
            fi
            ;;
        *)
            echo -e "${RED}错误：未知的核心类型：$CoreType${NC}"
            echo -e "${YELLOW}支持的核心类型：xray, sing, hysteria2${NC}"
            return 1
            ;;
    esac
    return 0
}

# 生成核心配置
generate_core_config() {
    cores_config=""
    if [ "$core_xray" = true ]; then
        cores_config=$(cat <<EOF
{
    "Type": "xray",
    "Log": {
        "Level": "$LogLevel",
        "ErrorPath": "/etc/V2bX/$LogLevel.log"
    },
    "OutboundConfigPath": "/etc/V2bX/custom_outbound.json",
    "RouteConfigPath": "/etc/V2bX/route.json"
}
EOF
        )
        if [ "$core_sing" = true ] || [ "$core_hysteria2" = true ]; then
            cores_config="$cores_config,"
        fi
    fi

    if [ "$core_sing" = true ]; then
        cores_config="$cores_config"$(cat <<EOF
{
    "Type": "sing",
    "Log": {
        "Level": "$LogLevel",
        "Timestamp": true
    },
    "NTP": {
        "Enable": true,
        "Server": "time.apple.com",
        "ServerPort": 0
    },
    "Experimental": {
        "ClashApi": {
            "ExternalController": "127.0.0.1:9090",
            "ExternalUI": "",
            "Secret": "",
            "DefaultMode": "rule",
            "StoreSelected": true,
            "StoreFakeIP": true
        }
    },
    "OriginalPath": "/etc/V2bX/sing_origin.json"
}
EOF
        )
        if [ "$core_hysteria2" = true ]; then
            cores_config="$cores_config,"
        fi
    fi

    if [ "$core_hysteria2" = true ]; then
        cores_config="$cores_config"$(cat <<EOF
{
    "Type": "hysteria2",
    "Log": {
        "Level": "$LogLevel"
    },
    "Hysteria2ConfigPath": "/etc/V2bX/hy2config.yaml",
    "Obfs": {
        "Type": "salamander",
        "Salamander": {
            "Password": "$(head -c 16 /dev/urandom | xxd -p)"
        }
    },
    "IgnoreClientBandwidth": false,
    "Masquerade": {
        "Type": "proxy",
        "Proxy": {
            "URL": "https://www.google.com",
            "RewriteHost": true
        }
    },
    "UdpIdleTimeout": 60,
    "Network": [
        "udp",
        "tcp"
    ]
}
EOF
        )
    fi

    cores_config="[$cores_config]"
}

# 生成节点配置
generate_node_config() {
    listen_ip="0.0.0.0"
    dns_env=$(cat <<EOF
{
    "CF_API_EMAIL": "$CF_API_EMAIL",
    "CF_API_KEY": "$CF_API_KEY"
}
EOF
    )
    node_config=$(cat <<EOF
{
    "Core": "$CoreType",
    "ApiHost": "$ApiHost",
    "ApiKey": "$ApiKey",
    "NodeID": $NodeID,
    "NodeType": "$NodeType",
    "Timeout": 30,
    "ListenIP": "$listen_ip",
    "SendIP": "0.0.0.0",
    "DeviceOnlineMinTraffic": 1000,
    "EnableProxyProtocol": false,
    "EnableUot": true,
    "EnableTFO": true,
    "DNSType": "UseIPv4",
    "CertConfig": {
        "CertMode": "$CertMode",
        "RejectUnknownSni": false,
        "CertDomain": "$CertDomain",
        "CertFile": "/etc/V2bX/fullchain.cer",
        "KeyFile": "/etc/V2bX/cert.key",
        "Email": "v2bx@github.com",
        "Provider": "cloudflare",
        "DNSEnv": $dns_env
    }
}
EOF
    )

    final_config=$(cat <<EOF
{
    "Log": {
        "Level": "$LogLevel",
        "Output": ""
    },
    "Cores": $cores_config,
    "Nodes": [
        $node_config
    ]
}
EOF
    )
    if ! mkdir -p /etc/V2bX || ! echo "$final_config" | jq . > $v2bx_config; then
        echo -e "${RED}配置文件写入失败，请检查权限${NC}" >&2
        exit 1
    fi
}

# 快速设置参数并启动
quick_setup() {
    clear   # 清除屏幕输出
    local start_time=$(date +%s.%N)
    display_config  # 显示生成前配置信息
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc)
    echo -e "${GREEN}本次加载耗时：$elapsed_time 秒${NC}" 
    # 处理命令行参数,支持全部变量参数
    for arg in "$@"; do
        case $arg in
            LogLevel=*)
                LogLevel="${arg#*=}"
                ;;
            ApiHost=*)
                ApiHost="${arg#*=}"
                ;;
            ApiKey=*)
                ApiKey="${arg#*=}"
                ;;
            NodeID=*)
                NodeID="${arg#*=}"
                ;;
            CoreType=*)
                CoreType="${arg#*=}"
                ;;
            NodeType=*)
                NodeType="${arg#*=}"
                ;;
            CertMode=*)
                CertMode="${arg#*=}"
                ;;
            CertDomain=*)
                CertDomain="${arg#*=}"
                ;;
            CF_API_EMAIL=*)
                CF_API_EMAIL="${arg#*=}"
                ;;
            CF_API_KEY=*)
                CF_API_KEY="${arg#*=}"
                ;;
            *)
                echo -e "${YELLOW}忽略非必要参数: $arg${NC}"
                ;;
        esac
    done
    echo -e "${GREEN}正在生成配置文件，请耐心等待...${NC}"
    local start_time=$(date +%s.%N)
    generate_full_config  # 生成完整配置
    local end_time=$(date +%s.%N)
    local elapsed_time=$(echo "$end_time - $start_time" | bc)
    echo -e "${GREEN}本次生成耗时：$elapsed_time 秒${NC}"
    display_config # 显示生成后配置信息
}

# 启动服务
generate_full_config() {
    if check_required_env && validate_core_node_types; then
        generate_core_config
        generate_node_config
        echo -e "${GREEN}配置文件已生成，输入 v2bx 命令启动${NC}"
    else
        echo -e "${RED}配置验证失败，请检查错误信息${NC}"
        exit 1
    fi
}

# 主函数
main() {
    # 如果有参数则使用快速设置模式
    if [ $# -gt 0 ]; then
        quick_setup "$@"
    else
        echo -e "${YELLOW} bash v2bx.sh ApiHost=https://api.example.com ApiKey=your_api_key NodeID=1 NodeType=vless ...${NC}"
        echo -e "${YELLOW} 遇到无法生成配置文件，执行 rm $v2bx_config 后重试${NC}"
    fi
}

# 执行主函数
main "$@"
#!/bin/bash

# This script manages outbound rules for specific destination CIDRs using SNAT on Debian systems.
# It supports IPv4 and IPv6 public IPs.
# Requires iptables and ip6tables. Will automatically install iptables-persistent if not present.
# Run as root: sudo ./script.sh

# Check and install iptables-persistent if not installed
if ! command -v netfilter-persistent &> /dev/null; then
    echo "安装 iptables-persistent 以确保规则持久化..."
    apt update
    apt install -y iptables-persistent
    if [ $? -ne 0 ]; then
        echo "错误：无法安装 iptables-persistent。请手动安装。"
        exit 1
    fi
fi

# Function to get all public IPv4 addresses
get_public_ipv4() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -vE '^127\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.|^192\.168\.' | sort -u
}

# Function to get all public IPv6 addresses (global unicast, excluding link-local and ULA)
get_public_ipv6() {
    ip -6 addr show | grep -oP '(?<=inet6\s)[0-9a-f:]+' | grep -E '^2' | grep -vE '^fe80|^fc' | sort -u
}

# Function to list all public IPs
list_public_ips() {
    echo "公网 IPv4 地址："
    get_public_ipv4
    echo ""
    echo "公网 IPv6 地址："
    get_public_ipv6
}

# Function to view current outbound rules
view_rules() {
    echo "IPv4 NAT POSTROUTING 规则："
    iptables -t nat -L POSTROUTING -n -v --line-numbers
    echo ""
    echo "IPv6 NAT POSTROUTING 规则："
    ip6tables -t nat -L POSTROUTING -n -v --line-numbers
}

# Function to add a rule
add_rule() {
    # List public IPs for selection
    echo "可用的公网 IP："
    list_public_ips
    echo ""

    # Ask for the public IP to use for outbound
    read -p "请输入用于出站的公网 IP（v4 或 v6）： " public_ip

    # Detect if IPv4 or IPv6
    if [[ $public_ip =~ \. ]]; then
        ip_type="v4"
        cmd="iptables"
    elif [[ $public_ip =~ : ]]; then
        ip_type="v6"
        cmd="ip6tables"
    else
        echo "无效的 IP 格式。"
        return
    fi

    # Ask for the destination CIDR
    read -p "请输入目标 CIDR（例如，192.168.1.0/24 或 2001:db8::/64）： " cidr

    # Validate CIDR matches IP type
    if [[ $ip_type == "v4" && $cidr =~ : ]] || [[ $ip_type == "v6" && $cidr =~ \. ]]; then
        echo "CIDR 类型与公网 IP 类型不匹配。"
        return
    fi

    # Ask for the rule name
    read -p "请输入规则名称： " rule_name

    # Add the SNAT rule for destination with comment
    $cmd -t nat -A POSTROUTING -d "$cidr" -m comment --comment "$rule_name" -j SNAT --to-source "$public_ip"
    echo "规则已添加。"

    # Save rules for persistence
    netfilter-persistent save
}

# Function to delete a rule
delete_rule() {
    # View rules first
    view_rules
    echo ""

    # Ask for IP type
    read -p "请输入 'v4' 表示 IPv4 或 'v6' 表示 IPv6： " ip_type
    if [[ $ip_type == "v4" ]]; then
        cmd="iptables"
    elif [[ $ip_type == "v6" ]]; then
        cmd="ip6tables"
    else
        echo "无效的选择。"
        return
    fi

    # Ask for the rule number to delete
    read -p "请输入要删除的规则编号： " rule_num

    # Delete the rule
    $cmd -t nat -D POSTROUTING "$rule_num"
    echo "规则已删除。"

    # Save rules
    netfilter-persistent save
}

# Function to edit a rule
edit_rule() {
    # View rules first
    view_rules
    echo ""

    # Ask for IP type
    read -p "请输入 'v4' 表示 IPv4 或 'v6' 表示 IPv6： " ip_type
    if [[ $ip_type == "v4" ]]; then
        cmd="iptables"
    elif [[ $ip_type == "v6" ]]; then
        cmd="ip6tables"
    else
        echo "无效的选择。"
        return
    fi

    # Ask for the rule number to edit
    read -p "请输入要编辑的规则编号： " rule_num

    # Get the current rule line using -S (show in save format)
    rule_line=$($cmd -t nat -S POSTROUTING | sed -n "${rule_num}p")

    if [ -z "$rule_line" ]; then
        echo "规则不存在。"
        return
    fi

    # Parse the current values
    # Assuming format: -A POSTROUTING -d CIDR -m comment --comment "NAME" -j SNAT --to-source IP
    current_cidr=$(echo "$rule_line" | grep -oP '(?<=-d )\S+')
    current_public_ip=$(echo "$rule_line" | grep -oP '(?<=--to-source )\S+')
    current_rule_name=$(echo "$rule_line" | grep -oP '(?<=--comment ")([^"]+)(?=")')

    # Prompt for new values, default to current
    read -p "当前目标 CIDR: $current_cidr，新值（回车保持不变）： " new_cidr
    new_cidr=${new_cidr:-$current_cidr}

    read -p "当前公网 IP: $current_public_ip，新值（回车保持不变）： " new_public_ip
    new_public_ip=${new_public_ip:-$current_public_ip}

    read -p "当前规则名称: $current_rule_name，新值（回车保持不变）： " new_rule_name
    new_rule_name=${new_rule_name:-$current_rule_name}

    # Validate new CIDR matches IP type
    if [[ $ip_type == "v4" && $new_cidr =~ : ]] || [[ $ip_type == "v6" && $new_cidr =~ \. ]]; then
        echo "新 CIDR 类型与公网 IP 类型不匹配。"
        return
    fi

    # Delete the old rule
    $cmd -t nat -D POSTROUTING "$rule_num"

    # Add the new rule
    $cmd -t nat -A POSTROUTING -d "$new_cidr" -m comment --comment "$new_rule_name" -j SNAT --to-source "$new_public_ip"
    echo "规则已编辑。"

    # Save rules
    netfilter-persistent save
}

# Main menu
while true; do
    echo ""
    echo "出站规则管理器"
    echo "1. 列出公网 IP"
    echo "2. 查看规则"
    echo "3. 添加规则"
    echo "4. 删除规则"
    echo "5. 编辑规则"
    echo "6. 退出"
    read -p "选择一个选项： " choice

    case $choice in
        1) list_public_ips ;;
        2) view_rules ;;
        3) add_rule ;;
        4) delete_rule ;;
        5) edit_rule ;;
        6) exit 0 ;;
        *) echo "无效的选项。" ;;
    esac
done
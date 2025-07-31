### Outbound Rule Manager Script

#### 功能简介
这个Bash脚本是一个交互式工具，用于在Debian系统上管理iptables/ip6tables的出站NAT规则（SNAT）。它允许用户通过指定目标CIDR地址和公网IP来控制网络流量出站，实现精细化的出口IP管理。脚本会自动读取系统配置的公网IPv4和IPv6地址，并支持规则的持久化（通过自动安装iptables-persistent）。

主要功能包括：
- **列出公网IP**：自动检测并显示系统所有公网IPv4和IPv6地址。
- **查看规则**：浏览当前IPv4和IPv6的POSTROUTING链NAT规则，包括编号和详情。
- **添加规则**：交互式输入目标CIDR、公网IP和规则名称（作为注释），添加SNAT规则。
- **删除规则**：根据IP类型（v4/v6）和规则编号删除指定规则。
- **编辑规则**：选择现有规则，修改CIDR、公网IP或规则名称，并重新应用。
- **规则持久化**：所有操作后自动保存规则，确保重启后生效。

脚本运行需要root权限（sudo），并在交互菜单中操作，支持IPv4和IPv6混合使用。该脚本由 AI 创建，已经在酷雪云多 V6 环境下测试通过。

#### 使用场景
这个脚本适用于需要多IP出口控制的网络环境，帮助解决流量路由、IP隔离或优化的问题。例如：
- **多IP服务器管理**：在云VPS或专用服务器上，有多个公网IP时，你可以指定某些目标网络（如特定网站或子网）的流量从特定IP出站，避免单一IP过载或被封禁。例如，为访问海外服务的流量分配专用出口IP。
- **网络安全与隔离**：在企业或个人防火墙设置中，为敏感目标CIDR（如内部子网或外部API）强制使用特定公网IP，实现流量隔离或合规要求。
- **开发/测试环境**：开发者在Debian容器或VM中测试网络路由时，快速添加/编辑规则来模拟不同出口场景，而无需手动编辑iptables命令。
- **负载均衡或冗余**：在有备用公网IP的系统中，针对高流量目标CIDR切换出口IP，提高可用性和性能。

通过这个脚本，用户可以避免复杂的命令行操作，快速配置和管理出站规则，适合网络管理员、DevOps工程师或Linux爱好者。

#### 脚本的使用方法
该脚本托管在GitHub上，线上链接为：https://github.com/yt1988/Multi-IP-Routing-Conf/raw/refs/heads/main/multi-ip-routing-conf.sh

在Debian系统中，您可以采用一键运行的方式快速部署和使用脚本。以下是推荐步骤：

1. **一键下载并运行（推荐，但请确保信任来源）**：
   使用curl直接下载并管道执行脚本：
   ```
   curl -sSL https://github.com/yt1988/Multi-IP-Routing-Conf/raw/refs/heads/main/multi-ip-routing-conf.sh | sudo bash
   ```
   这将自动下载脚本、检查并安装iptables-persistent（如果缺失），然后进入交互菜单。脚本需要root权限，因此使用sudo。

2. **手动下载并运行**：
   - 下载脚本：
     ```
     wget https://github.com/yt1988/Multi-IP-Routing-Conf/raw/refs/heads/main/multi-ip-routing-conf.sh -O multi-ip-routing-conf.sh
     ```
   - 赋予执行权限：
     ```
     chmod +x multi-ip-routing-conf.sh
     ```
   - 以root权限运行：
     ```
     sudo ./multi-ip-routing-conf.sh
     ```

运行后，脚本会显示主菜单，您可以通过数字选项（如1-6）进行操作。确保系统为Debian或兼容的衍生版（如Ubuntu），并已启用IPv4/IPv6转发（如果需要）。如果遇到问题，请检查系统日志或GitHub仓库的issue。

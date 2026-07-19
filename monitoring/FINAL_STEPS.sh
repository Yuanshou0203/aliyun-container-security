#!/bin/bash
# ============================================================
# 最终步骤: Grafana + Zabbix Agent + 端口收敛
# 在 docker-master (.10) 上执行
# ============================================================

echo "============================================"
echo "  最终步骤 - 请在 docker-master 上执行"
echo "============================================"

# ---- 1. 安装 Grafana ----
echo ""
echo ">>> [1/4] 安装 Grafana..."
cd /tmp
if ! rpm -qa | grep -q grafana; then
    # 尝试多个下载源
    curl -sL --connect-timeout 30 -o grafana.rpm \
        https://dl.grafana.com/oss/release/grafana-8.5.27-1.x86_64.rpm 2>&1 || \
    wget -q --timeout=30 -O grafana.rpm \
        https://dl.grafana.com/oss/release/grafana-8.5.27-1.x86_64.rpm 2>&1

    if [ -f grafana.rpm ] && [ -s grafana.rpm ]; then
        yum install -y ./grafana.rpm 2>&1 | tail -3
        systemctl start grafana-server
        systemctl enable grafana-server
        echo "Grafana 安装成功!"
    else
        echo "Grafana 下载失败, 请确保 VPN 开启后重试"
        echo "手动下载命令: curl -L -o /tmp/grafana.rpm https://dl.grafana.com/oss/release/grafana-8.5.27-1.x86_64.rpm"
        echo "然后执行: yum install -y /tmp/grafana.rpm && systemctl start grafana-server"
    fi
else
    systemctl start grafana-server
    echo "Grafana 已安装, 已启动"
fi

# ---- 2. 启动 Zabbix Server (如果还没起来) ----
echo ""
echo ">>> [2/4] 确认 Zabbix 服务..."
systemctl start zabbix-server 2>/dev/null
systemctl start zabbix-agent 2>/dev/null
echo "Zabbix Server: $(systemctl is-active zabbix-server)"
echo "Zabbix Agent:  $(systemctl is-active zabbix-agent)"

# ---- 3. 安装 Zabbix Agent 到 Docker 节点 ----
echo ""
echo ">>> [3/4] 在 Docker 节点上安装 Zabbix Agent..."

for node in docker-node1 docker-node2; do
    echo "--- $node ---"
    ssh -o StrictHostKeyChecking=no $node "
        rpm -qa | grep -q zabbix-agent || {
            rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm 2>&1 | tail -1
            yum install -y zabbix-agent 2>&1 | tail -1
        }
        sed -i 's/^Server=.*/Server=192.168.133.10/' /etc/zabbix/zabbix_agentd.conf
        sed -i 's/^ServerActive=.*/ServerActive=192.168.133.10/' /etc/zabbix/zabbix_agentd.conf
        sed -i 's/^Hostname=.*/Hostname=$node/' /etc/zabbix/zabbix_agentd.conf
        systemctl restart zabbix-agent
        systemctl enable zabbix-agent
        echo 'Zabbix Agent: ' \$(systemctl is-active zabbix-agent)
    "
done

# ---- 4. 端口收敛统计 ----
echo ""
echo ">>> [4/4] 端口收敛统计..."
echo ""
echo "  各节点对外端口:"
for host in docker-master docker-node1 docker-node2; do
    if [ "$host" = "docker-master" ]; then
        echo "  [$host]"
        ss -tlnp 2>/dev/null | grep -v '127.0.0.1\|::1' | awk '{print "    "$4" "$NF}' | sort -u
    else
        echo "  [$host]"
        ssh -o ConnectTimeout=3 $host 'ss -tlnp 2>/dev/null | grep -v "127.0.0.1\|::1"' | awk '{print "    "$4" "$NF}' | sort -u
    fi
done

echo ""
echo "============================================"
echo "  全部完成!"
echo "  Zabbix Web:  http://192.168.133.10:8081/zabbix"
echo "  Grafana:     http://192.168.133.10:3000"
echo "  (Zabbix 默认: Admin / zabbix)"
echo "  (Grafana 默认: admin / admin)"
echo "============================================"

#!/bin/bash
echo "============================================"
echo "  最终修复: Apache + Zabbix + Grafana"
echo "============================================"

# Fix 1: SELinux - allow Apache to use port 8081
echo ""
echo ">>> 修复 SELinux 端口限制..."
if command -v semanage &>/dev/null; then
    semanage port -a -t http_port_t -p tcp 8081 2>/dev/null || semanage port -m -t http_port_t -p tcp 8081 2>/dev/null
    echo "SELinux port 8081 added to http_port_t"
else
    # semanage not available, use setsebool
    setsebool -P httpd_can_network_connect 1 2>/dev/null
    echo "setsebool httpd_can_network_connect enabled"
fi

# Fix 2: Set ServerName to suppress AH00558 warning
echo ""
echo ">>> 配置 Apache ServerName..."
echo "ServerName docker-master" >> /etc/httpd/conf/httpd.conf

# Fix 3: Restart Apache
echo ""
echo ">>> 重启 Apache..."
systemctl restart httpd 2>&1
echo "Apache: $(systemctl is-active httpd)"

# Fix 4: Start Zabbix services
echo ""
echo ">>> 启动 Zabbix..."
systemctl start zabbix-server 2>&1
systemctl start zabbix-agent 2>&1
sleep 3
echo "Zabbix Server: $(systemctl is-active zabbix-server)"
echo "Zabbix Agent: $(systemctl is-active zabbix-agent)"

# Fix 5: Check Zabbix Server log for errors
echo ""
echo ">>> Zabbix Server 日志 (最近5行):"
journalctl -u zabbix-server --no-pager -n 5 2>/dev/null || tail -5 /var/log/zabbix/zabbix_server.log 2>/dev/null || echo "(日志不可用,检查 /var/log/zabbix/)"

# Fix 6: Install Grafana
echo ""
echo ">>> 安装 Grafana..."
if ! rpm -qa | grep -q grafana; then
    cd /tmp
    curl -sL -o grafana.rpm https://dl.grafana.com/oss/release/grafana-8.5.27-1.x86_64.rpm 2>&1 && \
    yum install -y ./grafana.rpm 2>&1 | tail -3 && \
    echo "Grafana RPM installed"

    systemctl start grafana-server 2>&1
    systemctl enable grafana-server 2>&1
    echo "Grafana: $(systemctl is-active grafana-server)"
else
    systemctl start grafana-server 2>&1
    echo "Grafana: $(systemctl is-active grafana-server)"
fi

# Final status
echo ""
echo "============================================"
echo "  最终状态"
echo "============================================"
for svc in httpd mariadb zabbix-server zabbix-agent grafana-server; do
    status=$(systemctl is-active $svc 2>&1)
    echo "  $svc: $status"
done

echo ""
echo "监听端口:"
ss -tlnp 2>/dev/null | grep -E ':8081|:3000|:10050|:10051' | awk '{print "  "$4" "$NF}'

echo ""
echo "============================================"
echo "  可通过以下地址访问:"
echo "  Zabbix: http://192.168.133.10:8081/zabbix"
echo "  Grafana: http://192.168.133.10:3000"
echo "  (默认账号: Admin / zabbix)"
echo "============================================"

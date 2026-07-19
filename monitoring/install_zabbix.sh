#!/bin/bash
# ============================================
# 安装 Zabbix Server + Grafana 监控平台
# 对应简历: 阿里云容器集群管控 - 个人工作 4
# ============================================

set -e
echo "============================================"
echo "  安装 Zabbix + Grafana 监控平台"
echo "  主机: $(hostname)"
echo "============================================"

# ---- 1. 安装 MariaDB (Zabbix 后端数据库) ----
echo ""
echo ">>> [1/8] 安装 MariaDB..."
rpm -qa | grep -q mariadb-server || yum install -y mariadb-server &>/dev/null
systemctl start mariadb
systemctl enable mariadb

# 创建 Zabbix 数据库和用户
mysql -u root << 'SQL' 2>/dev/null
CREATE DATABASE IF NOT EXISTS zabbix CHARACTER SET utf8 COLLATE utf8_bin;
GRANT ALL PRIVILEGES ON zabbix.* TO zabbix@localhost IDENTIFIED BY 'zabbix123';
FLUSH PRIVILEGES;
SQL
echo "  MariaDB 就绪, zabbix 数据库已创建"

# ---- 2. 安装 Zabbix 5.0 LTS ----
echo ""
echo ">>> [2/8] 安装 Zabbix 5.0 LTS..."
rpm -qa | grep -q zabbix-server || {
    rpm -Uvh https://repo.zabbix.com/zabbix/5.0/rhel/7/x86_64/zabbix-release-5.0-1.el7.noarch.rpm 2>&1 | tail -1
    yum install -y zabbix-server-mysql zabbix-agent zabbix-web-mysql 2>&1 | tail -3
}

# ---- 3. 导入 Zabbix 初始化数据 ----
echo ""
echo ">>> [3/8] 导入 Zabbix 数据库表..."
rpm -qa | grep -q zabbix-server-mysql && {
    zcat /usr/share/doc/zabbix-server-mysql-*/create.sql.gz | mysql -u zabbix -pzabbix123 zabbix 2>/dev/null
    echo "  Zabbix 数据库表导入完成"
}

# ---- 4. 配置 Zabbix Server ----
echo ""
echo ">>> [4/8] 配置 Zabbix Server..."
cat > /etc/zabbix/zabbix_server.conf << 'ZCFG'
LogFile=/var/log/zabbix/zabbix_server.log
LogFileSize=10
DBHost=localhost
DBName=zabbix
DBUser=zabbix
DBPassword=zabbix123
StartPollers=5
StartTrappers=5
CacheSize=8M
ZCFG

# ---- 5. 配置 PHP (Zabbix Web 前端) ----
echo ""
echo ">>> [5/8] 配置 PHP..."
yum install -y php php-mysql php-gd php-xml php-bcmath php-mbstring 2>&1 | tail -2

# 修改 PHP 时区
sed -i 's/;date.timezone =/date.timezone = Asia\/Shanghai/' /etc/php.ini 2>/dev/null || true
sed -i 's/date.timezone =/date.timezone = Asia\/Shanghai/' /etc/php.ini 2>/dev/null || true

# ---- 6. 配置 Zabbix Web ----
echo ""
echo ">>> [6/8] 配置 Zabbix Web 前端..."
cat > /etc/httpd/conf.d/zabbix.conf << 'HTTPCFG'
<VirtualHost *:8081>
    DocumentRoot /usr/share/zabbix
    <Directory /usr/share/zabbix>
        Options FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
HTTPCFG

# 安装 Apache (Zabbix Web 需要)
rpm -qa | grep -q httpd || yum install -y httpd 2>&1 | tail -1

# ---- 7. 启动所有服务 ----
echo ""
echo ">>> [7/8] 启动 Zabbix 服务..."
systemctl restart mariadb
systemctl restart httpd
systemctl start zabbix-server 2>/dev/null || true
systemctl start zabbix-agent
systemctl enable zabbix-server 2>/dev/null || true
systemctl enable zabbix-agent
systemctl enable httpd

# ---- 8. 安装 Grafana ----
echo ""
echo ">>> [8/8] 安装 Grafana..."
rpm -qa | grep -q grafana || {
    wget -q https://dl.grafana.com/oss/release/grafana-8.5.27-1.x86_64.rpm -O /tmp/grafana.rpm 2>&1 || \
    curl -sL https://dl.grafana.com/oss/release/grafana-8.5.27-1.x86_64.rpm -o /tmp/grafana.rpm
    yum install -y /tmp/grafana.rpm 2>&1 | tail -2
}
systemctl start grafana-server
systemctl enable grafana-server

# ---- 验证 ----
echo ""
echo "============================================"
echo "  安装验证"
echo "============================================"
echo ""
echo "Zabbix Server: $(systemctl is-active zabbix-server 2>/dev/null || echo 'checking...')"
echo "Zabbix Agent:  $(systemctl is-active zabbix-agent)"
echo "Grafana:       $(systemctl is-active grafana-server)"
echo "Apache:        $(systemctl is-active httpd)"
echo "MariaDB:       $(systemctl is-active mariadb)"
echo ""
echo "监听端口:"
ss -tlnp 2>/dev/null | grep -E ':80|:8081|:3000|:10050|:10051' || true
echo ""
echo "============================================"
echo "  Zabbix + Grafana 安装完成!"
echo "  Zabbix Web:   http://$(hostname -I | awk '{print $1}'):8081/zabbix"
echo "  Grafana:      http://$(hostname -I | awk '{print $1}'):3000"
echo "============================================"

#!/bin/bash
# ============================================
# Docker 安全加固脚本 (for .20 docker-node1 / .40 docker-node2)
# 对应简历: 阿里云容器集群管控 - 个人工作 1,2
# ============================================

echo "============================================"
echo "  Docker 安全加固开始"
echo "  主机: $(hostname)"
echo "============================================"

# ---- 1. Docker 守护进程安全配置 ----
echo ""
echo ">>> [1/6] Docker 守护进程安全参数..."

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'JSON'
{
  "icc": false,
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

systemctl daemon-reload
systemctl restart docker
echo "  daemon.json 配置完成: icc=false, no-new-privileges=true"

# ---- 2. 审计日志配置 ----
echo ""
echo ">>> [2/6] 配置 Docker 审计规则..."

cat > /etc/audit/rules.d/docker.rules << 'EOF'
-w /usr/bin/docker -p wa -k docker_actions
-w /var/lib/docker -p wa -k docker_changes
-w /etc/docker -p wa -k docker_config
-w /usr/lib/systemd/system/docker.service -p wa -k docker_service
EOF

# 如果 auditd 没装就装
rpm -qa | grep -q audit || yum install -y audit &>/dev/null
systemctl restart auditd 2>/dev/null || service auditd restart 2>/dev/null
auditctl -l 2>/dev/null
echo "  审计规则已配置"

# ---- 3. 启动一个安全的测试容器 ----
echo ""
echo ">>> [3/6] 启动安全加固的测试容器..."

# 清理旧容器
docker rm -f webapp 2>/dev/null

# 安全容器: 非root运行 + cap限制 + 资源限制 + 只读根文件系统
docker run -d --name webapp \
  --memory="256m" \
  --cpus="0.5" \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64M \
  --tmpfs /run:rw,noexec,nosuid,size=64M \
  --security-opt=no-new-privileges \
  nginx:alpine

echo "  安全容器已启动 (内存256m, cap-drop=ALL, read-only)"

# ---- 4. 验证容器安全配置 ----
echo ""
echo ">>> [4/6] 验证容器安全配置..."

echo "  [容器进程用户]:"
docker top webapp 2>/dev/null | head -3

echo ""
echo "  [容器资源限制]:"
docker inspect webapp --format 'Memory: {{.HostConfig.Memory}} bytes | CPUs: {{.HostConfig.NanoCpus}} | CapDrop: {{.HostConfig.CapDrop}}' 2>/dev/null

echo ""
echo "  [容器安全选项]:"
docker inspect webapp --format 'ReadOnly: {{.HostConfig.ReadonlyRootfs}} | NoNewPriv: {{.HostConfig.SecurityOpt}}' 2>/dev/null

# ---- 5. iptables 安全策略 ----
echo ""
echo ">>> [5/6] 配置 iptables 安全策略..."

# 允许已建立的连接
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# 允许内网 SSH
iptables -A INPUT -s 192.168.133.0/24 -p tcp --dport 22 -j ACCEPT

# 允许 Docker 内部通信
iptables -A INPUT -s 172.17.0.0/16 -j ACCEPT

# 限制 SSH 暴力破解
iptables -A INPUT -p tcp --dport 22 -m recent --set --name ssh_brute
iptables -A INPUT -p tcp --dport 22 -m recent --rcheck --seconds 60 --hitcount 3 --name ssh_brute -j DROP

# 记录拒绝的连接
iptables -A INPUT -j LOG --log-prefix "IPTABLES-DROP: " --log-level 4
iptables -A INPUT -j DROP

# 保存规则
mkdir -p /etc/iptables
iptables-save > /etc/iptables/rules.v4

echo "  iptables 规则已配置并保存"

# ---- 6. 端口收敛验证 ----
echo ""
echo ">>> [6/6] 端口收敛验证..."

echo "  当前监听端口 (非本地):"
ss -tlnp 2>/dev/null | grep -v "127.0.0.1" | grep -v "::1" || echo "  (无对外监听端口)"

echo ""
echo "============================================"
echo "  Docker 安全加固完成!"
echo "============================================"

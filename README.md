# 阿里云容器集群管控项目

## 📋 项目概述
基于阿里云 ECS + SLB 模拟搭建容器业务集群，实现 Docker 容器全生命周期安全管控、Ansible 自动化基线加固、Zabbix + Grafana 统一监控告警的完整闭环。

## 🏗️ 架构图

```
                    ┌─────────────────────────┐
                    │   docker-master (.10)    │
                    │   Ansible 主控节点        │
                    │   Zabbix Server          │
                    │   Grafana 监控面板        │
                    │   Nginx 反向代理          │
                    └──────────┬──────────────┘
                               │ SSH 免密
              ┌────────────────┼────────────────┐
              ▼                                 ▼
   ┌──────────────────┐             ┌──────────────────┐
   │  docker-node1    │             │  docker-node2    │
   │  192.168.133.20  │             │  192.168.133.40  │
   │  Docker CE       │             │  Docker CE       │
   │  Zabbix Agent    │             │  Zabbix Agent    │
   │  nginx:alpine    │             │  nginx:alpine    │
   └──────────────────┘             └──────────────────┘
```

## 🛠️ 技术栈
| 类别 | 技术 |
|------|------|
| 容器 | Docker CE, cgroup 资源隔离, Linux Capability 权限裁剪 |
| 自动化 | Ansible 2.9, SSH 免密批量管控 |
| 监控 | Zabbix 5.0 LTS + Grafana 8.5 |
| 安全 | iptables 安全组策略, auditd 审计日志, SELinux |
| 系统 | CentOS 7.9, VMware 虚拟化 |

## 📁 目录结构

```
├── ansible/
│   └── security_baseline.yml    # 安全基线加固 Playbook
├── docker/
│   ├── docker_security.sh       # Docker 安全配置脚本
│   └── fix_docker_mirror.sh     # 镜像加速配置
├── monitoring/
│   ├── install_zabbix.sh        # Zabbix Server 安装
│   ├── FINAL_STEPS.sh           # Grafana + Agent 部署
│   └── final_fix_10.sh          # 服务修复脚本
├── scripts/
│   └── install_ansible.sh       # Ansible 安装脚本
├── screenshots/                 # 截图目录
└── README.md
```

## ✨ 项目亮点

### 1. Docker 容器安全管控
- 非 root 运行：`--cap-drop=ALL --cap-add=NET_BIND_SERVICE`
- 资源限制：`--memory=256m --cpus=0.5`
- 只读文件系统：`--read-only` + tmpfs 挂载
- 审计日志：`auditd` 监控 Docker 操作

### 2. Ansible 自动化基线加固
- SSH 安全加固（禁用密码登录、空闲超时）
- 内核安全参数优化（SYN flood 防护、IP 转发禁用）
- 密码策略强制（90天过期、最小长度8）
- 批量下发，一键巡检

### 3. 端口收敛
- 公网高危端口暴露量下降 **70%**
- iptables 安全组策略（SSH 暴力破解防护、内网白名单）

### 4. 统一监控告警
- Zabbix 5.0 监控 CPU/内存/容器进程/网络流量
- Grafana 8.5 可视化仪表盘
- Agent 自动发现 + 告警规则

## 🚀 快速开始

```bash
# 1. Docker 安全配置（在 docker-node1/docker-node2 上）
bash docker/docker_security.sh

# 2. Ansible 基线加固（在 docker-master 上）
cd ansible && ansible-playbook security_baseline.yml

# 3. 部署监控（在 docker-master 上）
bash monitoring/FINAL_STEPS.sh
```

## 📊 验证结果

```bash
# Docker 安全验证
docker inspect webapp --format 'CapDrop:{{.HostConfig.CapDrop}} ReadOnly:{{.HostConfig.ReadonlyRootfs}}'

# Ansible 管控验证
ansible docker_nodes -m ping

# 端口收敛验证
ss -tlnp  # 对比加固前后
```

## 📝 相关项目
- [HIS 业务系统云上迁移](../his-cloud-migration) - 基于本项目的云基础设施，完成医疗业务迁移

---

> 🎓 应届生实训项目 | 独立完成 | 2025.07-2025.08

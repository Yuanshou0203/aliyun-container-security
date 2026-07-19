#!/bin/bash
echo "=== ��װ Ansible ==="
yum install -y epel-release 2>&1 | tail -1
yum install -y ansible 2>&1 | tail -3

echo ""
echo "=== ���� Ansible hosts ==="
cat > /etc/ansible/hosts << 'EOF'
[docker_nodes]
docker-node1 ansible_host=192.168.133.20
docker-node2 ansible_host=192.168.133.40

[all:vars]
ansible_user=root
ansible_ssh_pass=root
EOF

echo ""
echo "=== ��֤ ==="
ansible --version 2>&1 | head -1
echo ""
ansible docker_nodes -m ping -o 2>&1
echo ""
echo "=== Ansible ��װ��� ==="

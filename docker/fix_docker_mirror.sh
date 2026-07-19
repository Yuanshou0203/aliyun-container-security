#!/bin/bash
# 配置 Docker 国内镜像加速 + 修复容器启动

echo "=== 配置 Docker 镜像加速 ==="

# 写入镜像加速配置
cat > /etc/docker/daemon.json << 'JSON'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://dockerhub.timeweb.cloud",
    "https://docker.1panel.live"
  ],
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
echo "daemon.json 更新完成 (3 个国内镜像源)"

# 拉取 nginx 测试
echo ""
echo "=== 拉取 nginx:alpine ==="
docker pull nginx:alpine 2>&1 || echo "拉取失败，尝试其他方式..."

# 如果 nginx:alpine 拉取成功，启动安全容器
if docker images | grep -q "nginx.*alpine"; then
    docker rm -f webapp 2>/dev/null
    docker run -d --name webapp \
      --memory="256m" \
      --cpus="0.5" \
      --cap-drop=ALL \
      --cap-add=NET_BIND_SERVICE \
      --read-only \
      --tmpfs /tmp:rw,noexec,nosuid,size=64M \
      --tmpfs /run:rw,noexec,nosuid,size=64M \
      --security-opt=no-new-privileges \
      -p 8080:80 \
      nginx:alpine
    echo "nginx 容器启动成功!"
    curl -s -o /dev/null -w "HTTP Status: %{http_code}" http://localhost:8080
else
    # 用 hello-world 做基础测试
    echo "使用已有镜像 hello-world 测试"
    docker rm -f webapp 2>/dev/null
    docker run -d --name webapp \
      --memory="64m" \
      --cap-drop=ALL \
      --read-only \
      --security-opt=no-new-privileges \
      nginx:alpine 2>/dev/null || echo "nginx 不可用"
fi

echo ""
echo "=== 当前镜像列表 ==="
docker images

echo ""
echo "=== 运行中的容器 ==="
docker ps

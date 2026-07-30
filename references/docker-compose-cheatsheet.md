# Docker Compose 询问规则速查

## 流程总览

AI 生成 `docker-compose*.yml` 时，**先问两个问题**，再写文件：

```
1. 持久化用哪种？
   A. bind mount（推荐，主机目录可见，便于备份）
   B. 命名 volume（Docker 管理）
   C. 临时卷（容器删除时清理）
   D. 我自己说

2. 端口怎么暴露？
   A. 127.0.0.1（推荐，仅本机）
   B. 0.0.0.0（所有网卡，需要自己保证安全）
   C. 反向代理（容器绑 127.0.0.1，代理对外 0.0.0.0）
   D. 我自己说
```

用户在之前对话里已经表态、或者明确说"用推荐的"时，可以跳过询问。

## 方案对比

### 持久化方式对比

| 维度 | bind mount（A 推荐） | 命名 volume | 临时卷 |
|---|---|---|---|
| 数据位置 | 主机文件系统，看得见 | `/var/lib/docker/volumes/`，看不见 | 容器内，删除即清 |
| 备份 | `tar ./data/` 直接备份 | `docker run --rm -v vol:/data tar ...` | 不需备份 |
| 调试 | `vim ./data/db/postgresql.conf` | 要先 docker exec | 重启即重置 |
| 跨主机迁移 | `rsync ./data/` | 要先导出 volume | 不可迁移 |
| 适用场景 | 通用默认 | Docker Swarm 等编排系统 | 缓存/中间计算 |

bind mount 在所有持久化场景下都是更优选择（除非用编排系统）。

### 端口暴露方式对比

| 方案 | 安全性 | 适用场景 |
|---|---|---|
| **127.0.0.1** | ✅ 最高 | 开发、单服务器应用、配合反向代理 |
| **0.0.0.0** | ⚠️ 需自行保护 | 容器内已有完整认证、内网部署 |
| **反向代理** | ✅ 高 | 生产部署，需要 HTTPS、域名 |

## 为什么推荐这两者？

### bind mount 优于命名 volume

| 维度 | bind mount | 命名 volume |
|---|---|---|
| 数据位置 | 主机文件系统，看得见 | `/var/lib/docker/volumes/`，看不见 |
| 备份 | `tar ./data/` 直接备份 | `docker run --rm -v vol:/data tar ...` |
| 调试 | `vim ./data/db/postgresql.conf` | 要先 docker exec |
| 跨主机迁移 | `rsync ./data/` | 要先导出 volume |
| 性能 | 一致 | 一致 |

bind mount 在所有持久化场景下都是更优选择（除非用 Docker Swarm 这类编排系统，命名 volume 才有不可替代的作用）。

### 127.0.0.1 优于 0.0.0.0

- **安全**：容器端口不会意外暴露到公网
- **部署安全**：生产服务器上即使忘记配防火墙，数据库也不会被直接访问
- **开发体验**：本机仍然可访问（`localhost:8080`）

## 需要外部访问时的正确做法

**反例**（直接暴露）：

```yaml
services:
  web:
    ports:
      - "0.0.0.0:80:80"   # ❌ 容器直接对外
```

**正例**（用反向代理）：

```yaml
# docker-compose.yml
services:
  web:
    ports:
      - "127.0.0.1:8080:80"   # ✅ 仅本机

  nginx:
    image: nginx:alpine
    ports:
      - "0.0.0.0:80:80"       # ✅ 反向代理对外
    volumes:
      - ./config/nginx:/etc/nginx/conf.d:ro
    depends_on:
      - web
```

```nginx
# config/nginx/default.conf
upstream web_backend {
    server 127.0.0.1:8080;   # ✅ 指向 127.0.0.1
}

server {
    listen 80;
    location / {
        proxy_pass http://web_backend;
    }
}
```

这样：
- 容器端口仅本机（127.0.0.1）
- 反向代理监听 0.0.0.0:80
- 反向代理的 upstream 仍是 127.0.0.1:8080（容器端口）
- 攻击者穿透 nginx 后，看到的是 nginx 的 127.0.0.1 网络命名空间

## 常见错误与修复

### ❌ "volume: ./data:/data"（缺 type）

```yaml
volumes:
  - ./data:/data
```

虽然 Docker 默认按 bind mount 处理，但显式更清晰：

```yaml
volumes:
  - type: bind
    source: ./data
    target: /data
```

### ❌ 把 secrets 放进 bind mount 的目录

```yaml
volumes:
  - ./secrets:/etc/myapp/secrets  # ❌ 可能被 git 提交
```

应该用 Docker secrets 或环境变量：

```yaml
environment:
  DB_PASSWORD: ${DB_PASSWORD}   # ✅ 从 .env 读取
```

### ❌ bind mount 单个文件时忘了重新创建

```bash
# 修改主机配置后，容器不重启不会生效
vim ./config/postgresql/postgresql.conf
docker compose restart db
```

### ❌ 跨平台路径不一致（Mac vs Linux）

bind mount 路径必须是主机上的绝对或相对（相对 compose 文件）路径。在 Mac 上开发、Linux 上部署时，确保路径都有效。

```yaml
volumes:
  - ${PWD}/data:/data    # ✅ ${PWD} 跨平台
```

## 验证命令

```bash
# 查看实际生效的 volumes 配置
docker compose config --volumes

# 查看实际生效的端口
docker compose port web 80
# 输出: 127.0.0.1:8080
```

## 参考资料

- [Docker Compose 官方文档 - volumes](https://docs.docker.com/compose/compose-file/compose-file-v3/#volumes)
- [Docker 端口最佳实践](https://docs.docker.com/network/#published-ports)
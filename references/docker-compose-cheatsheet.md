# Docker Compose 安全规则速查

## 两条强制规则

### 1. 持久化 → bind mount

**所有需要持久化的目录必须 bind mount 到主机的 `./` 子目录，不使用命名 volume。**

| 场景 | bind mount 目标 |
|---|---|
| 应用代码 | `./app:/app` |
| 数据库数据 | `./data/db:/var/lib/postgresql/data` |
| 数据库配置 | `./config/postgres:/etc/postgresql/conf.d:ro` |
| 日志 | `./logs/web:/app/logs` |
| 上传文件 | `./uploads:/app/uploads` |
| Redis 数据 | `./data/redis:/data` |

**禁止在文件顶层声明 `volumes:` 块。**

### 2. 端口 → 127.0.0.1

**所有 `ports` 必须显式绑定到 `127.0.0.1`。**

| 写法 | 含义 | 是否允许 |
|---|---|---|
| `"127.0.0.1:8080:80"` | 仅本机访问容器 80 端口 | ✅ 推荐 |
| `"127.0.0.1:5432:5432"` | 仅本机访问数据库 | ✅ 推荐 |
| `"8080:80"` | 等价于 `0.0.0.0:8080:80`，暴露到所有网卡 | ❌ 禁止 |
| `"0.0.0.0:8080:80"` | 显式暴露到所有网卡 | ❌ 禁止 |

## 为什么这样？

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
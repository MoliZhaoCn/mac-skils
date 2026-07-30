# Docker Compose 部署示例

演示 macos-to-linux-compat skill 的两条 docker-compose 安全规则：

## 规则 1：持久化全部使用 bind mount

✅ 所有数据目录直接映射到主机的 `./` 子目录  
❌ 不使用命名 volume（不创建 `volumes:` 顶层块）

## 规则 2：端口绑定到 127.0.0.1

✅ 所有端口显式绑定到 `127.0.0.1`，仅本机访问  
❌ 不使用 `0.0.0.0` 或省略 host

## 文件清单

- `docker-compose.yml` — 三个服务的 compose 配置（web + db + redis）
- `.env.example` — 环境变量模板（复制为 `.env` 并填入实际值）

## 启动前准备

```bash
# 1. 创建数据目录（首次部署时执行）
mkdir -p app logs/web logs/db config/web config/postgres config/redis data/db data/redis

# 2. 复制环境变量
cp .env.example .env
# 编辑 .env 设置 DB_PASSWORD

# 3. 启动
docker compose up -d
```

## 目录结构（启动后）

```
.
├── docker-compose.yml
├── .env                         # 不入 git
├── app/                         # 应用代码 bind mount 源
├── logs/
│   ├── web/                     # web 日志
│   └── db/                      # postgres 日志
├── config/
│   ├── web/                     # web 配置
│   ├── postgres/                # postgres 配置
│   └── redis/                   # redis 配置
└── data/
    ├── db/                      # postgres 数据
    └── redis/                   # redis 数据
```

## 验证 bind mount 和端口

```bash
# 查看实际挂载（应该是 bind mount，不是 volume）
docker compose config --volumes

# 查看端口绑定（应该全是 127.0.0.1）
docker compose config --services | xargs -I {} docker compose port {} 80
```

## 需要外部访问时

参见 SKILL.md 的"需要外部访问时的切换"章节：用反向代理对外，容器端口仍保持 `127.0.0.1`。
# 国内源映射表

## 系统包管理器

### Debian / Ubuntu (apt)

清华源：
```
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bookworm-updates main contrib non-free non-free-firmware
deb https://mirrors.tuna.tsinghua.edu.cn/debian-security/ bookworm-security main contrib non-free non-free-firmware
```

替换命令：
```bash
sed -i 's|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g; \
        s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g' \
    /etc/apt/sources.list.d/*.list /etc/apt/sources.list
```

### RHEL / CentOS (yum / dnf)

阿里源：
```ini
[base]
name=CentOS-$releasever - Base
baseurl=https://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-$releasever
```

替换命令：
```bash
sed -i 's|mirrorlist.centos.org|mirrors.aliyun.com|g; \
        s|dl.fedoraproject.org|mirrors.aliyun.com|g' \
    /etc/yum.repos.d/*.repo
```

### Alpine (apk)

阿里源：
```
https://mirrors.aliyun.com/alpine/v3.18/main
https://mirrors.aliyun.com/alpine/v3.18/community
```

替换命令：
```bash
sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories
```

## 语言包管理器

| 工具 | 默认源 | 国内源 | 命令 |
|---|---|---|---|
| pip | pypi.org | pypi.tuna.tsinghua.edu.cn | `pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple` |
| npm | registry.npmjs.org | registry.npmmirror.com | `npm config set registry https://registry.npmmirror.com` |
| Go | proxy.golang.org | goproxy.cn | `go env -w GOPROXY=https://goproxy.cn,direct` |
| Cargo | crates.io | rsproxy.cn | 编辑 ~/.cargo/config.toml |
| Composer | packagist.org | mirrors.aliyun.com/composer | `composer config -g repo.packagist composer https://mirrors.aliyun.com/composer/` |

## Docker 镜像源

| 服务 | 默认 | 国内 |
|---|---|---|
| Docker Hub | docker.io | docker.1ms.run |

```bash
# /etc/docker/daemon.json
{
  "registry-mirrors": ["https://docker.1ms.run"]
}
```
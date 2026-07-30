# 跨平台归档与传输速查表

## tar 打包（Mac → Linux）

```bash
# 推荐写法：剥离所有 MacOS 扩展属性
tar --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/

# 加固：强制 uid/gid 为 0（root）
tar --owner=0 --group=0 \
    --no-acls --no-xattrs --no-fflags --no-mac-metadata \
    -czf archive.tar.gz files/
```

## tar 解压（Linux 上）

```bash
# 推荐：不要恢复原始所有者
tar -xzf archive.tar.gz --no-same-owner

# 查看归档内容
tar -tvf archive.tar.gz
```

## zip

```bash
zip -r archive.zip files/
unzip archive.zip
```

## rsync

```bash
# 跨平台传输，剥离扩展属性
rsync -avz --no-perms --no-owner --no-group --no-xattrs \
    -e ssh ./local/ user@host:/remote/

# 排除 MacOS 隐藏文件
rsync -avz --exclude='.DS_Store' --exclude='._*' \
    -e ssh ./local/ user@host:/remote/
```

## scp

```bash
scp archive.tar.gz user@host:/remote/path/
scp -r ./local-dir/ user@host:/remote/path/
```

## 参数速查

| 参数 | 作用 | MacOS | Linux |
|---|---|---|---|
| `--no-acls` | 不写入 ACL | ✅ | ✅ |
| `--no-xattrs` | 不写入扩展属性 | ✅ | ✅ |
| `--no-fflags` | 不写入文件标志 | ✅ | ✅ |
| `--no-mac-metadata` | 不写入 MacOS 特有元数据 | ✅（BSD tar） | ❌（GNU tar 报错） |
| `--owner=0` | 强制 uid 为 0 | ✅ | ✅ |
| `--no-same-owner` | 解压时不恢复所有者 | ✅ | ✅ |
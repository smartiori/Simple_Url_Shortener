# ShortURL 短链接服务部署文档

## 目录

1. [部署前准备](#部署前准备)
2. [目录结构说明](#目录结构说明)
3. [一键部署（推荐）](#一键部署推荐)
4. [手动部署步骤](#手动部署步骤)
5. [目录挂载说明](#目录挂载说明)
6. [常用管理命令](#常用管理命令)
7. [数据备份与恢复](#数据备份与恢复)
8. [故障排查](#故障排查)

---

## 部署前准备

### 服务器环境要求

- 操作系统：Linux（CentOS 7+/Ubuntu 18.04+/Debian 9+）
- 内存：最低 512MB，推荐 1GB 以上
- 磁盘：至少 1GB 可用空间
- 网络：端口 5000 开放

### 软件依赖

- Docker 19.03+

### 安装 Docker（如未安装）

```bash
# CentOS/RHEL
curl -fsSL https://get.docker.com | bash
systemctl start docker
systemctl enable docker

# Ubuntu/Debian
curl -fsSL https://get.docker.com | bash
systemctl start docker
systemctl enable docker
```

验证 Docker 安装：
```bash
docker --version
```

---

## 目录结构说明

部署完成后的目录结构如下：

```
/opt/shorturl/          # 应用根目录
├── deploy.sh           # 一键部署脚本
├── code/               # 代码目录（挂载到容器）
│   ├── app.py          # 主程序
│   ├── requirements.txt
│   └── Dockerfile
└── data/               # 数据目录（挂载到容器）
    └── urls.db         # SQLite 数据库文件
```

**重要说明：**
- `code/` 目录与容器内 `/app` 目录实时同步，修改代码无需进入容器
- `data/` 目录与容器内 `/app/data` 目录实时同步，可直接查看/备份数据库

---

## 一键部署（推荐）

### 步骤 1：上传部署文件

将以下文件上传到服务器 `/opt/shorturl/` 目录：
- `deploy.sh`
- 项目源代码文件

### 步骤 2：执行部署脚本

```bash
cd /opt/shorturl
chmod +x deploy.sh
./deploy.sh
```

脚本将自动完成以下操作：
1. 创建必要的目录结构
2. 构建 Docker 镜像
3. 停止旧容器（如存在）
4. 启动新容器并挂载目录
5. 验证服务运行状态

### 步骤 3：验证服务

访问：`http://服务器IP:5000`

---

## 手动部署步骤

### 步骤 1：创建目录结构

```bash
mkdir -p /opt/shorturl/{code,data}
cd /opt/shorturl
```

### 步骤 2：上传代码

将所有项目文件复制到 `/opt/shorturl/code/` 目录：
```bash
cp -r /path/to/shorturl/* /opt/shorturl/code/
```

### 步骤 3：构建 Docker 镜像

```bash
cd /opt/shorturl/code
docker build -t shorturl:latest .
```

### 步骤 4：启动容器

```bash
docker run -d \
  --name shorturl \
  --restart=always \
  -p 5000:5000 \
  -v /opt/shorturl/code:/app \
  -v /opt/shorturl/data:/app/data \
  shorturl:latest
```

### 步骤 5：验证部署

```bash
# 查看容器运行状态
docker ps | grep shorturl

# 查看服务日志
docker logs shorturl

# 健康检查
curl -I http://localhost:5000
```

---

## 目录挂载说明

### 代码目录挂载

**参数：** `-v /opt/shorturl/code:/app`

- 作用：将宿主机代码目录挂载到容器内
- 优势：
  - 修改代码无需重新构建镜像
  - 修改代码无需重启容器（部分修改需重启）
  - 可直接在宿主机使用编辑器修改代码

**代码修改流程：**
```bash
# 1. 修改宿主机上的代码
vi /opt/shorturl/code/app.py

# 2. 如需要，重启容器生效
docker restart shorturl
```

### 数据目录挂载

**参数：** `-v /opt/shorturl/data:/app/data`

- 作用：将 SQLite 数据库持久化到宿主机
- 优势：
  - 容器删除/重建不会丢失数据
  - 可直接在宿主机备份/查看数据库
  - 可直接使用 sqlite3 命令操作数据库

**查看数据库示例：**
```bash
# 安装 sqlite3
yum install -y sqlite3  # CentOS
# 或
apt-get install -y sqlite3  # Ubuntu/Debian

# 查看数据库
sqlite3 /opt/shorturl/data/urls.db ".tables"
sqlite3 /opt/shorturl/data/urls.db "SELECT * FROM urls;"
```

---

## 常用管理命令

### 服务管理

```bash
# 启动服务
docker start shorturl

# 停止服务
docker stop shorturl

# 重启服务
docker restart shorturl

# 查看运行状态
docker ps -a | grep shorturl
```

### 日志查看

```bash
# 查看实时日志
docker logs -f shorturl

# 查看最近 100 行日志
docker logs --tail 100 shorturl

# 查看错误日志
docker logs shorturl 2>&1 | grep -i error
```

### 进入容器

```bash
# 进入容器 shell
docker exec -it shorturl /bin/bash

# 直接在容器执行命令
docker exec -it shorturl python --version
```

### 版本升级

```bash
cd /opt/shorturl/code

# 1. 更新代码文件
# ... 上传新代码 ...

# 2. 重新构建镜像
docker build -t shorturl:latest .

# 3. 重建容器
docker rm -f shorturl
docker run -d \
  --name shorturl \
  --restart=always \
  -p 5000:5000 \
  -v /opt/shorturl/code:/app \
  -v /opt/shorturl/data:/app/data \
  shorturl:latest
```

---

## 数据备份与恢复

### 自动备份脚本

创建备份脚本 `/opt/shorturl/backup.sh`：

```bash
#!/bin/bash
BACKUP_DIR="/opt/shorturl/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份数据库
cp /opt/shorturl/data/urls.db $BACKUP_DIR/urls_backup_$DATE.db

# 删除 7 天前的备份
find $BACKUP_DIR -name "urls_backup_*.db" -mtime +7 -delete

echo "Backup completed: urls_backup_$DATE.db"
```

设置定时任务：
```bash
chmod +x /opt/shorturl/backup.sh
crontab -e
# 添加：0 2 * * * /opt/shorturl/backup.sh
```

### 手动备份

```bash
cp /opt/shorturl/data/urls.db /opt/shorturl/backups/urls_backup_$(date +%Y%m%d).db
```

### 数据恢复

```bash
# 停止服务
docker stop shorturl

# 恢复数据库
cp /opt/shorturl/backups/urls_backup_20240101.db /opt/shorturl/data/urls.db

# 启动服务
docker start shorturl
```

---

## 故障排查

### 容器无法启动

```bash
# 1. 查看容器日志
docker logs shorturl

# 2. 检查端口是否被占用
netstat -tlnp | grep 5000

# 3. 检查目录权限
ls -la /opt/shorturl/data/
ls -la /opt/shorturl/code/

# 4. 手动启动看错误
docker run --rm -p 5000:5000 \
  -v /opt/shorturl/code:/app \
  -v /opt/shorturl/data:/app/data \
  shorturl:latest
```

### 访问无响应

```bash
# 1. 检查防火墙
firewall-cmd --list-ports  # CentOS
ufw status                  # Ubuntu

# 2. 开放端口
firewall-cmd --add-port=5000/tcp --permanent
firewall-cmd --reload

# 3. 本地测试
curl http://localhost:5000
```

### 数据库问题

```bash
# 1. 检查数据库文件权限
ls -la /opt/shorturl/data/urls.db

# 2. 修复数据库权限
chmod 664 /opt/shorturl/data/urls.db
chown -R 1000:1000 /opt/shorturl/data/

# 3. 检查数据库完整性
sqlite3 /opt/shorturl/data/urls.db "PRAGMA integrity_check;"
```

### 联系技术支持

如遇问题，请收集以下信息：
1. 操作系统版本
2. Docker 版本：`docker --version`
3. 容器日志：`docker logs shorturl --tail 100`
4. 错误截图或具体报错信息

---

**文档版本：** v1.0  
**最后更新：** 2024-01-01

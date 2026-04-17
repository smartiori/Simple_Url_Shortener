# URL短链接应用部署文档

## 一、应用概述

本应用是一个基于Flask的URL短链接服务，使用SQLite作为数据库。

### 技术栈
- Python 3.9
- Flask 2.x
- SQLite 3

### 默认端口
- 应用端口: 5000

---

## 二、服务器要求

### 系统要求
- 操作系统: Linux (CentOS/Ubuntu/Debian等)
- 已安装Docker

### 硬件要求
- CPU: 1核及以上
- 内存: 512MB及以上
- 磁盘: 1GB及以上

---

## 三、目录结构

部署后的目录结构如下:

```
/opt/shorturl/
├── app/                    # 应用代码目录(挂载到容器)
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── data/                   # 数据库目录(挂载到容器)
│   └── urls.db
└── deploy.sh               # 一键部署脚本
```

---

## 四、部署步骤

### 步骤1: 准备部署目录

```bash
# 创建部署目录
sudo mkdir -p /opt/shorturl/app
sudo mkdir -p /opt/shorturl/data

# 设置权限
sudo chmod -R 755 /opt/shorturl
```

### 步骤2: 上传应用文件

将以下文件上传到服务器的 `/opt/shorturl/app/` 目录:
- app.py
- requirements.txt
- Dockerfile

```bash
# 使用scp上传(在本地执行)
scp -r app.py requirements.txt Dockerfile user@server:/opt/shorturl/app/
```

### 步骤3: 上传部署脚本

将 `deploy.sh` 上传到 `/opt/shorturl/` 目录并赋予执行权限:

```bash
chmod +x /opt/shorturl/deploy.sh
```

### 步骤4: 执行部署

```bash
cd /opt/shorturl
./deploy.sh
```

---

## 五、手动部署步骤(可选)

如果需要手动部署，请按以下步骤操作:

### 5.1 构建Docker镜像

```bash
cd /opt/shorturl/app
docker build -t shorturl-app:latest .
```

### 5.2 停止并删除旧容器(如果存在)

```bash
docker stop shorturl 2>/dev/null || true
docker rm shorturl 2>/dev/null || true
```

### 5.3 启动容器

```bash
docker run -d \
    --name shorturl \
    --restart unless-stopped \
    -p 5000:5000 \
    -v /opt/shorturl/app:/app \
    -v /opt/shorturl/data:/app/data \
    -e DATABASE_PATH=/app/data/urls.db \
    shorturl-app:latest
```

---

## 六、验证部署

### 6.1 检查容器状态

```bash
docker ps | grep shorturl
```

### 6.2 查看容器日志

```bash
docker logs shorturl
```

### 6.3 访问应用

打开浏览器访问: `http://服务器IP:5000`

---

## 七、常用运维命令

### 查看应用状态
```bash
docker ps -a | grep shorturl
```

### 查看实时日志
```bash
docker logs -f shorturl
```

### 重启应用
```bash
docker restart shorturl
```

### 停止应用
```bash
docker stop shorturl
```

### 启动应用
```bash
docker start shorturl
```

### 进入容器
```bash
docker exec -it shorturl /bin/bash
```

---

## 八、数据备份与恢复

### 备份数据库

```bash
# 备份数据库文件
cp /opt/shorturl/data/urls.db /opt/shorturl/data/urls.db.backup.$(date +%Y%m%d_%H%M%S)
```

### 恢复数据库

```bash
# 停止容器
docker stop shorturl

# 恢复数据库文件
cp /path/to/backup/urls.db /opt/shorturl/data/urls.db

# 启动容器
docker start shorturl
```

---

## 九、更新应用代码

由于代码目录已挂载到容器，修改代码后只需重启容器即可:

```bash
# 修改代码文件
vim /opt/shorturl/app/app.py

# 重启容器使更改生效
docker restart shorturl
```

如果修改了 `requirements.txt`，需要重新构建镜像:

```bash
cd /opt/shorturl/app
docker build -t shorturl-app:latest .
docker stop shorturl
docker rm shorturl
./deploy.sh
```

---

## 十、故障排查

### 问题1: 容器无法启动

**排查步骤:**
```bash
# 查看容器日志
docker logs shorturl

# 检查端口是否被占用
netstat -tlnp | grep 5000
```

### 问题2: 数据库文件权限问题

**解决方案:**
```bash
# 修改数据目录权限
sudo chmod -R 777 /opt/shorturl/data
```

### 问题3: 无法访问应用

**排查步骤:**
```bash
# 检查防火墙
sudo firewall-cmd --list-ports  # CentOS
sudo ufw status                 # Ubuntu

# 开放端口
sudo firewall-cmd --add-port=5000/tcp --permanent  # CentOS
sudo firewall-cmd --reload
sudo ufw allow 5000/tcp         # Ubuntu
```

---

## 十一、安全建议

1. **修改默认端口**: 在生产环境建议修改为其他端口
2. **配置反向代理**: 使用Nginx作为反向代理，配置HTTPS
3. **限制访问**: 配置防火墙规则限制访问来源
4. **定期备份**: 设置定时任务定期备份数据库

---

## 十二、联系支持

如有问题，请联系开发团队。

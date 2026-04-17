# FlaskShorty 部署文档

## 应用概述

FlaskShorty 是一个基于 Flask 和 SQLite 的轻量级 URL 短链服务，支持：
- 长链接生成短链
- 自动跳转
- 访问统计
- 后台数据查看

## 服务器要求

- **操作系统**: Linux (Ubuntu/CentOS/Debian 等) 或 macOS
- **Docker**: 已安装并运行 (Docker Desktop for Mac)
- **端口**: 5000 端口可用（可自定义）

## 目录结构说明

部署后服务器上的目录结构：

```
/opt/shorturl/              # 应用根目录
├── app/                    # 代码挂载目录（可修改代码）
│   └── app.py              # 主程序文件
├── data/                   # 数据库挂载目录
│   └── urls.db             # SQLite 数据库文件
├── deploy.sh               # 一键部署脚本
├── Dockerfile              # Docker 镜像构建文件
└── requirements.txt        # Python 依赖
```

## 部署步骤

### 方法一：一键部署（推荐）

1. 将项目文件上传到服务器 `/opt/shorturl/` 目录

2. 执行部署脚本：
```bash
cd /opt/shorturl
chmod +x deploy.sh
./deploy.sh
```

3. 访问应用：
   - 浏览器访问 `http://服务器IP:5000`

### 方法二：手动部署

1. 创建应用目录：
```bash
sudo mkdir -p /opt/shorturl/app /opt/shorturl/data
sudo chmod -R 755 /opt/shorturl
```

2. 复制文件到服务器：
   - `app.py` → `/opt/shorturl/app/`
   - `requirements.txt` → `/opt/shorturl/`
   - `Dockerfile` → `/opt/shorturl/`

3. 构建 Docker 镜像：
```bash
cd /opt/shorturl
sudo docker build -t shorturl:latest .
```

4. 运行容器：
```bash
sudo docker run -d \
  --name shorturl \
  -p 5000:5000 \
  -v /opt/shorturl/app:/app \
  -v /opt/shorturl/data:/data \
  --restart unless-stopped \
  shorturl:latest
```

## 常用管理命令

### 查看容器状态
```bash
sudo docker ps | grep shorturl
```

### 查看应用日志
```bash
sudo docker logs -f shorturl
```

### 重启应用
```bash
sudo docker restart shorturl
```

### 停止应用
```bash
sudo docker stop shorturl
```

### 删除容器（保留数据）
```bash
sudo docker rm -f shorturl
```

### 进入容器内部
```bash
sudo docker exec -it shorturl /bin/bash
```

## 数据管理

### 查看/修改代码

代码位于 `/opt/shorturl/app/app.py`，直接编辑即可生效（需要重启容器）：
```bash
sudo vim /opt/shorturl/app/app.py
sudo docker restart shorturl
```

### 备份数据库

数据库位于 `/opt/shorturl/data/urls.db`：
```bash
# 备份
sudo cp /opt/shorturl/data/urls.db /opt/shorturl/data/urls.db.backup.$(date +%Y%m%d)

# 查看数据库内容
sudo sqlite3 /opt/shorturl/data/urls.db "SELECT * FROM urls;"
```

### 修改端口

如需使用其他端口（如 8080），修改部署脚本中的 `HOST_PORT` 变量，或手动运行：
```bash
sudo docker run -d \
  --name shorturl \
  -p 8080:5000 \
  -v /opt/shorturl/app:/app \
  -v /opt/shorturl/data:/data \
  --restart unless-stopped \
  shorturl:latest
```

## 故障排查

### 容器无法启动
```bash
# 查看错误日志
sudo docker logs shorturl

# 检查端口占用
sudo netstat -tlnp | grep 5000
```

### 数据库权限问题
```bash
# 修复数据目录权限
sudo chmod -R 777 /opt/shorturl/data
sudo docker restart shorturl
```

### 代码修改未生效
修改 `/opt/shorturl/app/app.py` 后需要重启容器：
```bash
sudo docker restart shorturl
```

## 安全建议

1. **防火墙配置**: 仅开放必要的端口
```bash
sudo ufw allow 5000/tcp
```

2. **反向代理**: 生产环境建议使用 Nginx 反向代理
```nginx
server {
    listen 80;
    server_name your-domain.com;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

3. **定期备份**: 建议设置定时任务备份数据库
```bash
# 添加定时任务
crontab -e
# 每天凌晨2点备份
0 2 * * * cp /opt/shorturl/data/urls.db /opt/shorturl/backups/urls.db.$(date +\%Y\%m\%d)
```

## 联系方式

如有部署问题，请检查日志并参考本文档故障排查部分。

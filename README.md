
```markdown
# FlaskShorty - 简易自托管 URL 短链服务 🚀

一个基于 Flask 和 SQLite 的轻量级短网址生成器，适合部署在个人 VPS 上。支持链接生成、自动跳转、访问统计与后台管理。

## ✨ 特性

- 🧠 长链接一键生成短链
- ⚡ 快速跳转原始链接
- 📈 点击次数统计
- 🛠️ 简单易用的后台管理界面
- 🐍 依赖少、易于部署（Python + Flask）


## 🚀 快速开始

### 环境要求

- Python 3.8+
- Flask

### 安装依赖

```bash
pip install flask
```

### 启动服务

```bash
python app.py
```

默认运行在 `http://localhost:5000/`。

### 使用方式

- 首页：输入长链接，点击“生成短链”
- 管理页：访问 `/admin` 查看所有短链及访问统计

## 🗂️ 文件结构

```
.
├── app.py             # 主程序
├── templates/         # HTML 模板
│   ├── index.html
│   └── admin.html
├── static/            # 静态资源（可选）
├── db.sqlite3         # 数据库文件（自动生成）
└── README.md
```

## 🔒 TODO & 改进方向

- 添加用户登录权限管理
- 提供 RESTful API 接口
- 使用 Docker 封装部署
- 增加短链过期时间与密码保护

## 💡 许可协议

MIT License. 可自由使用、修改和部署。

## 🙌 感谢

项目灵感来自日常中对轻量短链服务的需求，欢迎 PR 与建议！


## 🐳 使用 Docker 部署
你可以使用 Docker 快速构建并运行该应用：​

🛠️ 构建镜像
在项目根目录下执行以下命令：​

```bash
docker build -t flaskshorty .
```

🚀 运行容器
构建完成后，运行以下命令启动容器：​

```bash
docker run -d -p 5000:5000 --name flaskshorty flaskshorty
```
应用将运行在 http://localhost:5000/
你可以在浏览器中访问该地址来使用短链接服务。​

🧹 停止并删除容器
如需停止并删除容器，可执行以下命令：​

```bash
docker stop flaskshorty
docker rm flaskshorty
```

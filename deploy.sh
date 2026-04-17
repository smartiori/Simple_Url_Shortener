#!/bin/bash

# FlaskShorty 一键部署脚本
# 适用于 Linux 服务器，使用纯 Docker 命令（不支持 docker compose）

set -e

# 配置变量
APP_NAME="shorturl"
IMAGE_NAME="shorturl:latest"
HOST_PORT=5000
CONTAINER_PORT=5000

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 获取脚本所在目录的绝对路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  FlaskShorty 一键部署脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检测操作系统类型
OS_TYPE="$(uname -s)"

# 检查是否以 root 权限运行 (Linux 需要，macOS 不需要)
if [ "$OS_TYPE" = "Linux" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}警告: 未使用 root 权限运行，可能需要 sudo${NC}"
        DOCKER_CMD="sudo docker"
    else
        DOCKER_CMD="docker"
    fi
elif [ "$OS_TYPE" = "Darwin" ]; then
    # macOS 不需要 sudo
    DOCKER_CMD="docker"
    echo -e "${GREEN}  检测到 macOS 系统${NC}"
else
    # 其他系统默认不需要 sudo
    DOCKER_CMD="docker"
fi

# 检查 Docker 是否安装
echo -e "${YELLOW}[1/6] 检查 Docker 环境...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}错误: Docker 未安装，请先安装 Docker${NC}"
    exit 1
fi

# 检查 Docker 服务是否运行
if ! $DOCKER_CMD info &> /dev/null; then
    echo -e "${RED}错误: Docker 服务未运行，请先启动 Docker${NC}"
    exit 1
fi
echo -e "${GREEN}  Docker 环境正常${NC}"

# 创建必要的目录
echo -e "${YELLOW}[2/6] 创建应用目录...${NC}"
mkdir -p "${SCRIPT_DIR}/app"
mkdir -p "${SCRIPT_DIR}/data"
mkdir -p "${SCRIPT_DIR}/backups"

# 确保代码文件存在
if [ ! -f "${SCRIPT_DIR}/app/app.py" ]; then
    if [ -f "${SCRIPT_DIR}/app.py" ]; then
        cp "${SCRIPT_DIR}/app.py" "${SCRIPT_DIR}/app/"
        echo -e "${GREEN}  已复制 app.py 到 app 目录${NC}"
    else
        echo -e "${RED}  错误: 未找到 app.py 文件${NC}"
        exit 1
    fi
fi

# 确保 Dockerfile 存在
if [ ! -f "${SCRIPT_DIR}/Dockerfile" ]; then
    echo -e "${RED}  错误: 未找到 Dockerfile 文件${NC}"
    exit 1
fi

# 确保 requirements.txt 存在
if [ ! -f "${SCRIPT_DIR}/requirements.txt" ]; then
    echo -e "${RED}  错误: 未找到 requirements.txt 文件${NC}"
    exit 1
fi

echo -e "${GREEN}  目录结构已准备${NC}"

# 停止并删除旧容器
echo -e "${YELLOW}[3/6] 清理旧容器...${NC}"
if $DOCKER_CMD ps -a --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
    echo -e "  发现旧容器，正在停止并删除..."
    $DOCKER_CMD stop "${APP_NAME}" &> /dev/null || true
    $DOCKER_CMD rm "${APP_NAME}" &> /dev/null || true
    echo -e "${GREEN}  旧容器已清理${NC}"
else
    echo -e "${GREEN}  无旧容器需要清理${NC}"
fi

# 删除旧镜像（可选）
if $DOCKER_CMD images --format '{{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
    echo -e "  发现旧镜像，正在删除..."
    $DOCKER_CMD rmi "${IMAGE_NAME}" &> /dev/null || true
fi

# 构建 Docker 镜像
echo -e "${YELLOW}[4/6] 构建 Docker 镜像...${NC}"
cd "${SCRIPT_DIR}"
$DOCKER_CMD build -t "${IMAGE_NAME}" .
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  镜像构建成功${NC}"
else
    echo -e "${RED}  镜像构建失败${NC}"
    exit 1
fi

# 运行容器
echo -e "${YELLOW}[5/6] 启动应用容器...${NC}"
$DOCKER_CMD run -d \
    --name "${APP_NAME}" \
    -p "${HOST_PORT}:${CONTAINER_PORT}" \
    -v "${SCRIPT_DIR}/app:/app" \
    -v "${SCRIPT_DIR}/data:/data" \
    --restart unless-stopped \
    "${IMAGE_NAME}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}  容器启动成功${NC}"
else
    echo -e "${RED}  容器启动失败${NC}"
    exit 1
fi

# 等待容器启动
echo -e "${YELLOW}[6/6] 等待应用启动...${NC}"
sleep 3

# 检查容器状态
if $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${APP_NAME}$"; then
    echo -e "${GREEN}  应用运行正常${NC}"
else
    echo -e "${RED}  应用启动失败，请检查日志${NC}"
    echo -e "  查看日志: $DOCKER_CMD logs ${APP_NAME}"
    exit 1
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  部署成功！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 根据操作系统获取 IP 地址
if [ "$OS_TYPE" = "Darwin" ]; then
    # macOS 获取 IP 地址
    IP_ADDR=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n 1)
    if [ -z "$IP_ADDR" ]; then
        IP_ADDR="localhost"
    fi
else
    # Linux 获取 IP 地址
    IP_ADDR=$(hostname -I | awk '{print $1}')
fi

echo -e "应用访问地址: ${GREEN}http://${IP_ADDR}:${HOST_PORT}${NC}"
echo -e "或: ${GREEN}http://localhost:${HOST_PORT}${NC}"
echo ""
echo -e "常用命令:"
echo -e "  查看日志: ${YELLOW}$DOCKER_CMD logs -f ${APP_NAME}${NC}"
echo -e "  重启应用: ${YELLOW}$DOCKER_CMD restart ${APP_NAME}${NC}"
echo -e "  停止应用: ${YELLOW}$DOCKER_CMD stop ${APP_NAME}${NC}"
echo -e "  查看状态: ${YELLOW}$DOCKER_CMD ps | grep ${APP_NAME}${NC}"
echo ""
echo -e "数据目录: ${YELLOW}${SCRIPT_DIR}/data/${NC}"
echo -e "代码目录: ${YELLOW}${SCRIPT_DIR}/app/${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"

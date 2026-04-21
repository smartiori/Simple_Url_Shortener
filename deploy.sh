#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

APP_NAME="shorturl"
PORT=5000
IMAGE_NAME="shorturl:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

detect_environment() {
    OS_TYPE="$(uname -s)"
    
    if [[ "${OS_TYPE}" == "Darwin" ]]; then
        echo -e "${YELLOW}检测到 macOS 环境，使用当前目录作为工作目录${NC}"
        APP_DIR="${SCRIPT_DIR}"
        CODE_DIR="${APP_DIR}"
        DATA_DIR="${APP_DIR}/data"
    else
        APP_DIR="/opt/shorturl"
        CODE_DIR="${APP_DIR}/code"
        DATA_DIR="${APP_DIR}/data"
    fi
}

check_mount_permission() {
    echo -e "\n${YELLOW}检查 Docker 挂载权限...${NC}"
    
    TEST_DIR="${CODE_DIR}"
    mkdir -p "${TEST_DIR}"
    
    if docker run --rm -v "${TEST_DIR}:/test" busybox ls /test >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Docker 挂载权限正常${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ 当前目录无 Docker 挂载权限，切换到用户目录${NC}"
        APP_DIR="$HOME/shorturl"
        CODE_DIR="${APP_DIR}/code"
        DATA_DIR="${APP_DIR}/data"
        echo -e "${GREEN}✓ 新的工作目录: ${APP_DIR}${NC}"
    fi
}

echo -e "${GREEN}"
echo "=========================================="
echo "   ShortURL 短链接服务一键部署脚本"
echo "=========================================="
echo -e "${NC}"

check_docker() {
    echo -e "${YELLOW}[1/8] 检查 Docker 环境...${NC}"
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}错误: 未检测到 Docker，请先安装 Docker${NC}"
        echo "安装命令: curl -fsSL https://get.docker.com | bash"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        echo -e "${RED}错误: Docker 服务未启动${NC}"
        echo "启动命令: systemctl start docker"
        exit 1
    fi

    DOCKER_VERSION=$(docker --version | awk '{print $3}')
    echo -e "${GREEN}✓ Docker 版本: ${DOCKER_VERSION}${NC}"
}

create_directories() {
    echo -e "\n${YELLOW}[4/8] 创建目录结构...${NC}"
    
    mkdir -p "${CODE_DIR}"
    mkdir -p "${DATA_DIR}"
    
    echo -e "${GREEN}✓ 应用目录: ${APP_DIR}${NC}"
    echo -e "${GREEN}✓ 代码目录: ${CODE_DIR}${NC}"
    echo -e "${GREEN}✓ 数据目录: ${DATA_DIR}${NC}"
}

copy_code() {
    echo -e "\n${YELLOW}[3/8] 复制应用代码...${NC}"
    
    if [ "${SCRIPT_DIR}" != "${CODE_DIR}" ]; then
        mkdir -p "${CODE_DIR}"
        cp -r "${SCRIPT_DIR}/"* "${CODE_DIR}/"
        echo -e "${GREEN}✓ 代码已复制到 ${CODE_DIR}${NC}"
    else
        echo -e "${GREEN}✓ 代码已在正确位置${NC}"
    fi
    
    ls -la "${CODE_DIR}/"
}

build_image() {
    echo -e "\n${YELLOW}[5/8] 构建 Docker 镜像...${NC}"
    
    cd "${CODE_DIR}"
    
    if docker images | grep -q "${IMAGE_NAME%:*}"; then
        echo -e "${YELLOW}  发现旧镜像，正在删除...${NC}"
        docker rmi -f "${IMAGE_NAME}" 2>/dev/null || true
    fi
    
    docker build -t "${IMAGE_NAME}" .
    
    echo -e "${GREEN}✓ 镜像构建完成${NC}"
    docker images | grep shorturl
}

stop_old_container() {
    echo -e "\n${YELLOW}[6/8] 停止旧容器（如存在）...${NC}"
    
    if docker ps -a | grep -q "${APP_NAME}"; then
        echo -e "${YELLOW}  停止并删除旧容器...${NC}"
        docker stop "${APP_NAME}" 2>/dev/null || true
        docker rm -f "${APP_NAME}" 2>/dev/null || true
        echo -e "${GREEN}✓ 旧容器已清理${NC}"
    else
        echo -e "${GREEN}✓ 无旧容器需要清理${NC}"
    fi
}

start_container() {
    echo -e "\n${YELLOW}[7/8] 启动容器...${NC}"
    
    docker run -d \
        --name "${APP_NAME}" \
        --restart=always \
        -p "${PORT}:5000" \
        -v "${CODE_DIR}:/app" \
        -v "${DATA_DIR}:/app/data" \
        "${IMAGE_NAME}"
    
    echo -e "${GREEN}✓ 容器启动成功${NC}"
    sleep 3
}

health_check() {
    echo -e "\n${YELLOW}[8/8] 健康检查...${NC}"
    
    if docker ps | grep -q "${APP_NAME}"; then
        echo -e "${GREEN}✓ 容器运行状态: 正常${NC}"
    else
        echo -e "${RED}✗ 容器运行状态: 异常${NC}"
        echo "容器日志:"
        docker logs "${APP_NAME}" --tail 30
        exit 1
    fi
    
    MAX_RETRIES=10
    RETRY_COUNT=0
    echo -e "${YELLOW}  等待服务就绪...${NC}"
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT} | grep -q "200\|302"; then
            echo -e "${GREEN}✓ 服务健康检查: 通过${NC}"
            break
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 2
    done
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${YELLOW}⚠ 服务响应超时，请手动检查${NC}"
        echo "容器日志:"
        docker logs "${APP_NAME}" --tail 30
    fi
}

get_host_ip() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        echo "127.0.0.1"
    else
        hostname -I | awk '{print $1}'
    fi
}

show_summary() {
    echo -e "\n${GREEN}"
    echo "=========================================="
    echo "          部署完成！"
    echo "=========================================="
    echo -e "${NC}"
    echo "📌 访问地址:    http://$(get_host_ip):${PORT}"
    echo "📁 代码目录:    ${CODE_DIR}"
    echo "💾 数据目录:    ${DATA_DIR}"
    echo "🐳 容器名称:    ${APP_NAME}"
    echo ""
    echo "常用命令:"
    echo "  查看日志:    docker logs -f ${APP_NAME}"
    echo "  重启服务:    docker restart ${APP_NAME}"
    echo "  停止服务:    docker stop ${APP_NAME}"
    echo "  进入容器:    docker exec -it ${APP_NAME} /bin/bash"
    echo ""
    echo -e "${GREEN}详细部署说明请查看 DEPLOY.md 文件${NC}"
    echo ""
}

main() {
    detect_environment
    
    if [[ "$(uname -s)" != "Darwin" && "$(id -u)" != "0" ]]; then
        echo -e "${YELLOW}⚠ 建议使用 root 用户执行此脚本${NC}"
        echo "  或使用: sudo $0"
        echo ""
    fi
    
    check_docker
    check_mount_permission
    create_directories
    copy_code
    build_image
    stop_old_container
    start_container
    health_check
    show_summary
}

main "$@"

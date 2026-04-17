#!/bin/bash

set -e

APP_NAME="shorturl"
IMAGE_NAME="shorturl-app"
IMAGE_TAG="latest"
CONTAINER_NAME="shorturl"
APP_PORT=5000

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

detect_os() {
    OS_TYPE="linux"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_TYPE="mac"
    fi
    log_info "检测到操作系统: ${OS_TYPE}"
}

setup_directories() {
    detect_os
    
    if [ "${OS_TYPE}" == "mac" ]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        DEPLOY_DIR="${SCRIPT_DIR}"
        APP_DIR="${DEPLOY_DIR}"
        DATA_DIR="${DEPLOY_DIR}/data"
        
        log_info "Mac模式: 使用当前项目目录"
        log_debug "项目目录: ${DEPLOY_DIR}"
    else
        DEPLOY_DIR="/opt/shorturl"
        APP_DIR="${DEPLOY_DIR}/app"
        DATA_DIR="${DEPLOY_DIR}/data"
        
        log_info "Linux模式: 使用标准部署目录"
        log_debug "部署目录: ${DEPLOY_DIR}"
    fi
    
    export DEPLOY_DIR APP_DIR DATA_DIR
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker未运行，请先启动Docker"
        exit 1
    fi
    
    log_info "Docker已安装: $(docker --version)"
}

create_directories() {
    log_info "创建数据目录..."
    mkdir -p "${DATA_DIR}"
    
    if [ "${OS_TYPE}" == "linux" ]; then
        chmod -R 755 "${DEPLOY_DIR}"
    fi
    
    log_info "目录创建完成:"
    log_debug "  应用目录: ${APP_DIR}"
    log_debug "  数据目录: ${DATA_DIR}"
}

build_image() {
    log_info "构建Docker镜像..."
    
    if [ ! -f "${APP_DIR}/Dockerfile" ]; then
        log_error "Dockerfile不存在: ${APP_DIR}/Dockerfile"
        exit 1
    fi
    
    cd "${APP_DIR}"
    docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
    log_info "镜像构建完成: ${IMAGE_NAME}:${IMAGE_TAG}"
}

stop_container() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "停止并删除旧容器..."
        docker stop "${CONTAINER_NAME}" 2>/dev/null || true
        docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    fi
}

start_container() {
    log_info "启动容器..."
    
    docker run -d \
        --name "${CONTAINER_NAME}" \
        --restart unless-stopped \
        -p ${APP_PORT}:${APP_PORT} \
        -v "${APP_DIR}:/app" \
        -v "${DATA_DIR}:/app/data" \
        -e DATABASE_PATH=/app/data/urls.db \
        "${IMAGE_NAME}:${IMAGE_TAG}"
    
    log_info "容器启动成功"
}

check_status() {
    log_info "检查容器状态..."
    sleep 2
    
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        log_info "容器运行正常"
        
        if [ "${OS_TYPE}" == "mac" ]; then
            log_info "应用访问地址: http://localhost:${APP_PORT}"
        else
            log_info "应用访问地址: http://服务器IP:${APP_PORT}"
        fi
        
        echo ""
        log_info "常用命令:"
        log_info "  查看日志: docker logs ${CONTAINER_NAME}"
        log_info "  实时日志: docker logs -f ${CONTAINER_NAME}"
        log_info "  进入容器: docker exec -it ${CONTAINER_NAME} /bin/bash"
    else
        log_error "容器启动失败，请检查日志"
        docker logs "${CONTAINER_NAME}" 2>/dev/null || true
        exit 1
    fi
}

show_usage() {
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  deploy    - 完整部署(构建镜像+启动容器)"
    echo "  start     - 启动容器"
    echo "  stop      - 停止容器"
    echo "  restart   - 重启容器"
    echo "  status    - 查看状态"
    echo "  logs      - 查看日志"
    echo "  rebuild   - 重新构建镜像并部署"
    echo "  clean     - 清理容器和镜像"
    echo "  help      - 显示帮助信息"
    echo ""
    echo "系统兼容:"
    echo "  - Mac系统: 使用当前项目目录部署(适合开发测试)"
    echo "  - Linux系统: 使用/opt/shorturl目录部署(适合生产环境)"
    echo ""
    echo "示例:"
    echo "  $0 deploy    # 首次部署"
    echo "  $0 restart   # 重启应用"
    echo "  $0 logs      # 查看实时日志"
}

deploy() {
    log_info "开始部署 ${APP_NAME}..."
    check_docker
    setup_directories
    create_directories
    build_image
    stop_container
    start_container
    check_status
    log_info "部署完成!"
}

start() {
    setup_directories
    log_info "启动容器..."
    docker start "${CONTAINER_NAME}" 2>/dev/null || {
        log_warn "容器不存在，执行完整部署..."
        deploy
    }
    log_info "容器已启动"
}

stop() {
    log_info "停止容器..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    log_info "容器已停止"
}

restart() {
    setup_directories
    log_info "重启容器..."
    docker restart "${CONTAINER_NAME}" 2>/dev/null || {
        log_warn "容器不存在，执行完整部署..."
        deploy
    }
    log_info "容器已重启"
}

status() {
    setup_directories
    echo ""
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    
    if [ -f "${DATA_DIR}/urls.db" ]; then
        log_info "数据库文件: ${DATA_DIR}/urls.db"
        ls -lh "${DATA_DIR}/urls.db" 2>/dev/null || true
    fi
}

logs() {
    docker logs -f "${CONTAINER_NAME}"
}

rebuild() {
    log_info "重新构建并部署..."
    check_docker
    setup_directories
    build_image
    stop_container
    start_container
    check_status
    log_info "重新构建完成!"
}

clean() {
    log_warn "清理容器和镜像..."
    docker stop "${CONTAINER_NAME}" 2>/dev/null || true
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
    docker rmi "${IMAGE_NAME}:${IMAGE_TAG}" 2>/dev/null || true
    log_info "清理完成"
}

case "${1:-deploy}" in
    deploy)
        deploy
        ;;
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    status)
        status
        ;;
    logs)
        logs
        ;;
    rebuild)
        rebuild
        ;;
    clean)
        clean
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        log_error "未知命令: $1"
        show_usage
        exit 1
        ;;
esac

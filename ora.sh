#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 메시지를 출력하는 함수
function show() {
    echo -e "${CYAN}$1${NC}"
}

# curl 설치 여부 확인
if ! command -v curl &> /dev/null
then
    show "${YELLOW}curl을 찾을 수 없습니다. curl을 설치하는 중...${NC}"
    sudo apt update && sudo apt install -y curl
else
    show "${GREEN}curl이 이미 설치되어 있습니다.${NC}"
fi
echo

# 도커 설치 확인
echo -e "${BOLD}${CYAN}Docker 설치 확인 중...${NC}"
if command -v docker >/dev/null 2>&1; then
    echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
else
    echo -e "${RED}Docker가 설치되어 있지 않습니다. Docker를 설치하는 중입니다...${NC}"
    sudo apt update && sudo apt install -y curl net-tools
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    echo -e "${GREEN}Docker가 성공적으로 설치되었습니다.${NC}"
fi

# tora 디렉토리를 만들고 이동
show "${BLUE}tora 디렉토리를 생성하고 이동합니다...${NC}"
mkdir -p tora && cd tora

# docker-compose.yml 파일 생성
show "${BLUE}docker-compose.yml 파일을 생성합니다...${NC}"
cat <<EOF > docker-compose.yml
services:
  confirm:
    image: oraprotocol/tora:confirm
    container_name: ora-tora
    depends_on:
      - redis
      - openlm
    command: 
      - "--confirm"
    env_file:
      - .env
    environment:
      REDIS_HOST: 'redis'
      REDIS_PORT: 6379
      CONFIRM_MODEL_SERVER_13: 'http://openlm:5000/'
    networks:
      - private_network
  redis:
    image: oraprotocol/redis:latest
    container_name: ora-redis
    restart: always
    networks:
      - private_network
  openlm:
    image: oraprotocol/openlm:latest
    container_name: ora-openlm
    restart: always
    networks:
      - private_network
  diun:
    image: crazymax/diun:latest
    container_name: diun
    command: serve
    volumes:
      - "./data:/data"
      - "/var/run/docker.sock:/var/run/docker.sock"
    environment:
      - "TZ=Asia/Shanghai"
      - "LOG_LEVEL=info"
      - "LOG_JSON=false"
      - "DIUN_WATCH_WORKERS=5"
      - "DIUN_WATCH_JITTER=30"
      - "DIUN_WATCH_SCHEDULE=0 0 * * *"
      - "DIUN_PROVIDERS_DOCKER=true"
      - "DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true"
    restart: always

networks:
  private_network:
    driver: bridge
EOF

# 사용자로부터 프라이빗 키와 각종 URL 입력 받기
echo -e "${YELLOW}해당 사이트에 방문하여 각각의 필요한 엔드포인트를 받으세요.${NC}"
echo -e "${YELLOW}https://dashboard.alchemy.com/apps${NC}"
echo
read -p "$(echo -e ${CYAN}EVM프라이빗 키를 입력하세요\(노드전용 버너지갑\): ${NC})" PRIV_KEY
read -p "$(echo -e ${CYAN}Ethereum 메인넷의 Alchemy WSS URL을 입력하세요: ${NC})" MAINNET_WSS
read -p "$(echo -e ${CYAN}Ethereum 메인넷의 Alchemy HTTP URL을 입력하세요: ${NC})" MAINNET_HTTP
read -p "$(echo -e ${CYAN}Sepolia Ethereum의 Alchemy WSS URL을 입력하세요: ${NC})" SEPOLIA_WSS
read -p "$(echo -e ${CYAN}Sepolia Ethereum의 Alchemy HTTP URL을 입력하세요: ${NC})" SEPOLIA_HTTP

# .env 파일 생성
show "${BLUE}.env 파일을 생성합니다...${NC}"
cat <<EOF > .env
############### 민감한 설정 ###############

PRIV_KEY="$PRIV_KEY"

############### 일반 설정 ###############

TORA_ENV=production

MAINNET_WSS="$MAINNET_WSS"
MAINNET_HTTP="$MAINNET_HTTP"
SEPOLIA_WSS="$SEPOLIA_WSS"
SEPOLIA_HTTP="$SEPOLIA_HTTP"

REDIS_TTL=86400000

############### 앱별 설정 ###############

CONFIRM_CHAINS='["sepolia"]'
CONFIRM_MODELS='[13]'

CONFIRM_USE_CROSSCHECK=true
CONFIRM_CC_POLLING_INTERVAL=3000
CONFIRM_CC_BATCH_BLOCKS_COUNT=300

CONFIRM_TASK_TTL=2592000000
CONFIRM_TASK_DONE_TTL=2592000000
CONFIRM_CC_TTL=2592000000
EOF

# 시스템 메모리 오버커밋 설정
show "${BLUE}시스템 메모리 오버커밋을 설정합니다...${NC}"
sudo sysctl vm.overcommit_memory=1
echo

# Docker 컨테이너 시작 안내 메시지
show "${YELLOW}docker-compose를 사용하여 Docker 컨테이너를 시작합니다. (5~10분 소요될 수 있습니다)...${NC}"
echo
sudo docker compose up

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"

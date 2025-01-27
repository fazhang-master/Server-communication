#!/bin/bash

# 在本地机器上生成 SSH 密钥 ssh-keygen -t rsa -b 4096
# 将公钥复制到远程服务器 ssh-copy-id -i ~/.ssh/id_rsa.pub user@hostname -p PORT
# 远程传输文件 rsync -av --progress --partial --append-verify -e "ssh -p $PORT" "$SOURCE" "$HOST:$DESTINATION"

# 默认日志文件
LOG_FILE="rsync.log"
DEFAULT_PORT=22

# 帮助信息
show_help() {
  cat <<EOF
用法: $0 [选项]...
选项:
  -p, --PASSWORD        远程主机密码 (如果已经配置了公钥验证，可省略)
  -h, --HOST            远程主机地址 (必须指定)
  -P, --PORT            SSH端口 (默认: 22)
  -s, --SOURCE          源路径 (必须指定)
  -d, --DESTINATION     目标路径 (必须指定)
  -u, --upload          上传模式: 本地 -> 远程
  -l, --download        下载模式: 远程 -> 本地
  -L, --log             指定日志文件路径 (默认: rsync.log)
  -H, --help            显示帮助信息
EOF
  exit 0
}

# 初始化参数
MODE=""
PASSWORD=""
HOST=""
PORT=$DEFAULT_PORT
SOURCE=""
DESTINATION=""

# 参数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--PASSWORD) PASSWORD="$2"; shift 2;;
    -h|--HOST) HOST="$2"; shift 2;;
    -P|--PORT) PORT="$2"; shift 2;;
    -s|--SOURCE) SOURCE="$2"; shift 2;;
    -d|--DESTINATION) DESTINATION="$2"; shift 2;;
    -u|--upload) MODE="upload"; shift;;
    -l|--download) MODE="download"; shift;;
    -L|--log) LOG_FILE="$2"; shift 2;;
    -H|--help) show_help;;
    *) echo "未知选项: $1"; show_help; exit 1;;
  esac
done

# 检查必要参数
if [[ -z $HOST || -z $SOURCE || -z $DESTINATION || -z $MODE ]]; then
  echo "错误: 必须指定主机、源路径、目标路径以及模式 (上传或下载)"
  show_help
fi

# 日志记录
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查 rsync 是否安装
if ! command -v rsync &>/dev/null; then
  log_message "错误: rsync 未安装，请先安装 rsync."
  exit 1
fi

# 检查路径是否存在
if [[ $MODE == "upload" && ! -e $SOURCE ]]; then
  log_message "错误: 源路径不存在: $SOURCE"
  exit 1
fi

# 同步逻辑
log_message "开始同步文件 (模式: $MODE)..."

SSH_OPTIONS="-p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
RSYNC_CMD="rsync -avz --progress --partial --append-verify -e \"ssh $SSH_OPTIONS\""

if [[ $MODE == "upload" ]]; then
  if [[ -z $PASSWORD ]]; then
    eval "$RSYNC_CMD \"$SOURCE\" \"$HOST:$DESTINATION\""
  else
    sshpass -p "$PASSWORD" eval "$RSYNC_CMD \"$SOURCE\" \"$HOST:$DESTINATION\""
  fi
elif [[ $MODE == "download" ]]; then
  if [[ -z $PASSWORD ]]; then
    eval "$RSYNC_CMD \"$HOST:$SOURCE\" \"$DESTINATION\""
  else
    sshpass -p "$PASSWORD" eval "$RSYNC_CMD \"$HOST:$SOURCE\" \"$DESTINATION\""
  fi
else
  log_message "错误: 未知模式 $MODE"
  exit 1
fi

if [[ $? -eq 0 ]]; then
  log_message "文件同步成功!"
else
  log_message "文件同步失败，请检查日志文件: $LOG_FILE"
fi
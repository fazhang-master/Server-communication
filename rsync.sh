#!/bin/bash

# 在本地机器上生成 SSH 密钥 ssh-keygen -t rsa -b 4096
# 将公钥复制到远程服务器 ssh-copy-id -i ~/.ssh/id_rsa.pub user@hostname -p PORT
# 远程传输文件 rsync -av --progress --partial --append-verify -e "ssh -p $PORT" "$SOURCE" "$HOST:$DESTINATION"

# 默认配置
LOG_FILE="rsync.log"
DEFAULT_PORT=22
RETRY_INTERVAL=10         # 延长重试间隔
MAX_RETRY=20              # 最大重试次数
CHUNK_SIZE="10G"          # 分块大小

# 帮助信息
show_help() {
  cat <<EOF
用法: $0 [选项]...
选项:
  -p, --PASSWORD        远程主机密码
  -h, --HOST            远程主机地址 (格式：username@ip)
  -P, --PORT            SSH端口 (默认: 22)
  -s, --SOURCE          源路径 (必须指定)
  -d, --DESTINATION     目标路径 (必须指定)
  -u, --upload          上传模式: 本地 -> 远程
  -l, --download        下载模式: 远程 -> 本地
  -c, --chunk           启用分块传输 (默认分块大小: $CHUNK_SIZE)
  -b, --bwlimit         带宽限制 (单位: KB/s)
  -L, --log             指定日志文件路径 (默认: $LOG_FILE)
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
USE_CHUNK=false
BW_LIMIT=""

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
    -c|--chunk) USE_CHUNK=true; shift;;
    -b|--bwlimit) BW_LIMIT="--bwlimit=$2"; shift 2;;
    -L|--log) LOG_FILE="$2"; shift 2;;
    -H|--help) show_help;;
    *) echo "未知选项: $1"; show_help; exit 1;;
  esac
done

# 日志记录
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检查必要参数
if [[ -z $HOST || -z $SOURCE || -z $DESTINATION || -z $MODE ]]; then
  log_message "错误: 必须指定主机、源路径、目标路径以及模式"
  show_help
fi

# 核心优化：SSH保活配置
SSH_OPTIONS="-p $PORT -o StrictHostKeyChecking=no \
             -o UserKnownHostsFile=/dev/null \
             -o ServerAliveInterval=30 \
             -o ServerAliveCountMax=3"

# 构建rsync命令
RSYNC_CMD="rsync -av --progress --partial --append-verify $BW_LIMIT -e \"ssh $SSH_OPTIONS\""

# 分块传输函数
transfer_chunks() {
  local parts=( $1 )
  for part in "${parts[@]}"; do
    retry_count=0
    while [[ $retry_count -lt $MAX_RETRY ]]; do
      if [[ $MODE == "upload" ]]; then
        eval "$RSYNC_CMD \"$part\" \"$HOST:$DESTINATION/\""
      else
        eval "$RSYNC_CMD \"$HOST:$part\" \"$DESTINATION/\""
      fi

      if [[ $? -eq 0 ]]; then
        log_message "分块 $part 传输成功"
        break
      else
        ((retry_count++))
        log_message "分块 $part 传输失败 (重试 $retry_count/$MAX_RETRY)"
        sleep $RETRY_INTERVAL
      fi
    done
  done
}

# 主传输逻辑
retry_count=0
while [[ $retry_count -lt $MAX_RETRY ]]; do
  if $USE_CHUNK; then
    # 分块传输模式
    if [[ $MODE == "upload" ]]; then
      parts=$(split -b $CHUNK_SIZE --verbose "$SOURCE" "${SOURCE}_part_" | awk '{print $NF}')
      transfer_chunks "$parts"
      ssh $HOST "cat $DESTINATION/${SOURCE}_part_* > $DESTINATION/$SOURCE"
    else
      ssh $HOST "split -b $CHUNK_SIZE $SOURCE ${SOURCE}_part_"
      transfer_chunks "${SOURCE}_part_*"
      cat $DESTINATION/${SOURCE}_part_* > $DESTINATION/$SOURCE
    fi
  else
    # 整文件传输模式
    if [[ $MODE == "upload" ]]; then
      if [[ -z $PASSWORD ]]; then
        eval "$RSYNC_CMD \"$SOURCE\" \"$HOST:$DESTINATION\""
      else
        sshpass -p "$PASSWORD" eval "$RSYNC_CMD \"$SOURCE\" \"$HOST:$DESTINATION\""
      fi
    else
      if [[ -z $PASSWORD ]]; then
        eval "$RSYNC_CMD \"$HOST:$SOURCE\" \"$DESTINATION\""
      else
        sshpass -p "$PASSWORD" eval "$RSYNC_CMD \"$HOST:$SOURCE\" \"$DESTINATION\""
      fi
    fi
  fi

  if [[ $? -eq 0 ]]; then
    log_message "文件同步成功!"
    exit 0
  else
    ((retry_count++))
    log_message "传输失败 (重试 $retry_count/$MAX_RETRY)"
    sleep $RETRY_INTERVAL
  fi
done

log_message "错误: 达到最大重试次数($MAX_RETRY)，传输终止"
exit 1

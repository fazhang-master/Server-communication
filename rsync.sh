#!/bin/bash

# 在本地机器上生成 SSH 密钥 ssh-keygen -t rsa -b 4096
# 将公钥复制到远程服务器 ssh-copy-id -i ~/.ssh/id_rsa.pub user@hostname -p PORT
# 远程传输文件 rsync -av --progress --partial --append-verify -e "ssh -p $PORT" "$SOURCE" "$HOST:$DESTINATION"

# 替换为你的密码
PASSWORD='duo4aiKi'

# 替换为你的目标服务器和端口
HOST='root@s1.v100.vip'
PORT='23582'
SOURCE='./chatbot/aibot_public_api.zip'
DESTINATION='/mnt/data/zf/'

# 检查 rsync 是否安装
if ! command -v rsync &> /dev/null
then
    echo "rsync could not be found, please install rsync."
    exit 1
fi

# 开始循环
while true
do
    echo "开始同步文件..."
    sshpass -p "$PASSWORD" rsync -avz --progress --partial --append-verify -e "ssh -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" "$SOURCE" "$HOST:$DESTINATION"
    # 检查 rsync 命令是否成功执行
    if [ $? -eq 0 ]; then
        echo "文件同步成功!"
        break  # 成功后退出循环
    else
        error_code=$?
        echo "文件同步失败，错误码: $error_code"
        echo "等待3秒后再次尝试..."
        sleep 3  # 等待3秒后重试
    fi
done

echo "同步过程完成或停止。"
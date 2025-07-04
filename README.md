# 简介

rsync.sh 是一个基于 rsync 和 ssh 的文件同步脚本工具，支持从本地上传到远程或从远程下载到本地。

# 功能

1.	支持上传与下载：用户可以自由选择本地到远程或远程到本地的传输方向。。
2.	日志功能：自动记录同步日志。

# 环境准备

1. 安装 rsync 和 sshpass：

   ```bash
   sudo apt install rsync sshpass
   ```

2. 配置 SSH 公钥（推荐）：

   ```bash
   ssh-keygen -t rsa -b 4096
   ssh-copy-id -i ~/.ssh/id_rsa.pub user@hostname -p PORT
   ```

# 参数

   - `-p, --PASSWORD`  

    远程主机密码（如果已经配置了公钥验证，可省略）


   \- `-h, --HOST`  

    远程主机地址 (必须指定；格式：username@ip)


   \- `-P, --PORT`  

    SSH 端口（默认：22）


   \- `-s, --SOURCE`  

    源路径（必须指定）


   \- `-d, --DESTINATION`  

    目标路径（必须指定）   


   \- `-u, --upload`  

    上传模式：本地 → 远程


   \- `-l, --download`  

    下载模式：远程 → 本地

   - `-c, --chunk`  

    启用分块传输（大文件必备），默认分块大小 10G (源路径必须是文件)

   \- `-b, --bwlimit`  

    带宽限制（单位：KB/s）

  \- `-L, --log`  

    指定日志文件路径（默认：rsync.log）


   \- `-H, --help`  

    显示帮助信息

# 使用说明

1. 查看帮助：

   ```bash
   ./rsync.sh --help
   ```

2. 上传文件（本地到远程）：

   ```bash
   ./rsync.sh -p 密码 -h 主机 -P 端口 -s 本地路径 -d 远程路径 -u
   ```

3. 下载文件（远程到本地）：

   ```bash
   ./rsync.sh -p 密码 -h 主机 -P 端口 -s 远程路径 -d 本地路径 -l
   ```

4. 分块上传大文件：

   ```bash
   ./rsync.sh -p 密码 -h 主机 -P 端口 -s 远程文件路径 -d 本地路径 -l -c
   ```

5. 使用带宽限制 (10MB/s)：

   ```bash
   ./rsync.sh -p 密码 -h 主机 -P 端口 -s 远程文件路径 -d 本地路径 -l -b 10240 -c
   ```

6. 示例：

- 上传：

  ```bash
  ./rsync.sh -p "mypassword" -h "user@192.168.1.1" -P 22 -s "/local/path" -d "/remote/path" -u
  ```

- 下载：

  ```bash
  ./rsync.sh -p "mypassword" -h "user@192.168.1.1" -P 22 -s "/remote/path" -d "/local/path" -l	
  ```

- 分块上传+带宽限制：

  ```bash
  ./rsync.sh -p "mypassword" -h "user@192.168.1.1" -P 22 -s "/remote/filepath" -d "/local/path" -l -b 5120 -c
  ```


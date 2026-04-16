#!/bin/bash

dir_shell=/ql/shell
. $dir_shell/share.sh
. $dir_shell/env.sh

echo -e "======================写入rclone配置========================\n"
mkdir -p ~/.config/rclone
echo "$RCLONE_CONF" > ~/.config/rclone/rclone.conf

echo -e "======================1. 检测配置文件========================\n"
import_config "$@"
make_dir /etc/nginx/conf.d
make_dir /run/nginx
init_nginx
fix_config

pm2 l &>/dev/null

echo -e "======================2. 安装依赖========================\n"
patch_version

echo -e "======================3. 启动nginx========================\n"
nginx -s reload 2>/dev/null || nginx -c /etc/nginx/nginx.conf
echo -e "nginx启动成功...\n"

echo -e "======================4. 启动pm2服务========================\n"
reload_update
reload_pm2

if [[ $AutoStartBot == true ]]; then
  echo -e "======================5. 启动bot========================\n"
  nohup ql bot >$dir_log/bot.log 2>&1 &
  echo -e "bot后台启动中...\n"
fi

if [[ $EnableExtraShell == true ]]; then
  echo -e "====================6. 执行自定义脚本========================\n"
  nohup ql extra >$dir_log/extra.log 2>&1 &
  echo -e "自定义脚本后台执行中...\n"
fi

echo -e "############################################################\n"
echo -e "容器启动成功..."
echo -e "############################################################\n"

echo -e "##########写入登陆信息############"
dir_root=/ql && source /ql/shell/api.sh 

init_auth_info() {
  local body="$1"
  local tip="$2"
  local currentTimeStamp=$(date +%s)
  local api=$(
    curl -s --noproxy "*" "http://0.0.0.0:5600/api/user/init?t=$currentTimeStamp" \
      -X 'PUT' \
      -H "Accept: application/json" \
      -H "User-Agent: Mozilla/5.0" \
      -H "Content-Type: application/json;charset=UTF-8" \
      --data-raw "{$body}"
  )
  code=$(echo "$api" | jq -r .code)
  message=$(echo "$api" | jq -r .message)
  if [[ $code == 200 ]]; then
    echo -e "${tip}成功🎉"
  else
    echo -e "${tip}失败(${message})"
  fi
}

init_auth_info "\"username\": \"$ADMIN_USERNAME\", \"password\": \"$ADMIN_PASSWORD\"" "Change Password"

echo -e "##########同步备份（rclone）############"

if [ -n "$RCLONE_CONF" ]; then
  REMOTE_FOLDER="huggingface:/qinglong"

  OUTPUT=$(rclone ls "$REMOTE_FOLDER" 2>&1)
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    if [ -z "$OUTPUT" ]; then
      echo "初次安装（远程为空）"
    else
      mkdir -p /ql/.tmp/data
      if rclone sync "$REMOTE_FOLDER" /ql/.tmp/data; then
        echo -e "🎉同步成功🎉"
        real_time=true ql reload data
      else
        echo -e "❌同步失败，请检查 rclone 配置或网络"
      fi
    fi
  elif [[ "$OUTPUT" == *"directory not found"* ]]; then
    echo "错误：远程文件夹不存在"
  else
    echo "错误：$OUTPUT"
  fi
else
  echo "没有检测到 Rclone 配置信息"
fi

if [ -n "$NOTIFY_CONFIG" ]; then
    python /notify.py
    dir_root=/ql && source /ql/shell/api.sh && notify_api '青龙服务启动通知' '青龙面板成功启动'
else
    echo "没有检测到通知配置信息，不进行通知"
fi

echo -e "##########启动 code-server############"
export PASSWORD=$ADMIN_PASSWORD
code-server --bind-addr 0.0.0.0:7860 --port 7860 &

tail -f /dev/null

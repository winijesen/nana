#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-09-15-QINGLONG-2.21.0-DEBIAN-RENDER-FINAL-V8 🔥🔥🔥"

set -e


################################################
# 基础环境
################################################

export PATH="$HOME/bin:$PATH"


QL_DIR=/ql
dir_shell=$QL_DIR/shell


echo "HOME=$HOME"
echo "USER=$(whoami)"



################################################
# 加载青龙环境
################################################

if [ -f "$dir_shell/share.sh" ]; then

    source "$dir_shell/share.sh"

else

    echo "⚠️ 未找到 share.sh"

fi




################################################
# rclone
################################################


echo "======================写入 rclone 配置========================"


if [ -n "$RCLONE_CONF" ]; then


mkdir -p "$HOME/.config/rclone"


echo "$RCLONE_CONF" \
> "$HOME/.config/rclone/rclone.conf"


chmod 600 "$HOME/.config/rclone/rclone.conf"


echo "✔ rclone配置完成"


else


echo "没有检测到 RCLONE_CONF"


fi






################################################
# Render PORT
################################################


echo "Render PORT=$PORT"



################################################
# 固定青龙端口
################################################


if [ -f "$QL_DIR/.env" ]; then


sed -i \
"s/^PORT=.*/PORT=5700/" \
"$QL_DIR/.env"


fi


echo "✔ 青龙固定端口5700"






################################################
# 启动青龙 PM2
################################################


echo "[INFO]启动PM2"



# 这里恢复青龙官方方式

if command -v reload_pm2 >/dev/null 2>&1

then

    reload_pm2


else


    echo "使用青龙PM2恢复"


    pm2 resurrect || true


fi




pm2 status || true






################################################
# 等待青龙
################################################


echo "等待青龙启动..."


for i in {1..30}

do


if curl -sf \
http://127.0.0.1:5700/api/health \
>/dev/null 2>&1

then


echo "✔ 青龙启动完成"


break


fi



sleep 2


done







################################################
# nginx
################################################


echo "======================启动 nginx========================"



if [ -f /etc/nginx/conf.d/front.conf ]

then


envsubst '$PORT' \
< /etc/nginx/conf.d/front.conf \
> /tmp/front.conf



mv /tmp/front.conf \
/etc/nginx/conf.d/front.conf



echo "✔ nginx PORT替换完成"


fi




nginx -t



if nginx -s reload 2>/dev/null

then


echo "✔ nginx reload"


else


nginx


echo "✔ nginx启动完成"


fi







################################################
# 管理员初始化
################################################


sleep 5



if [ -n "$ADMIN_USERNAME" ] && \
[ -n "$ADMIN_PASSWORD" ]

then


echo "########## 初始化管理员 ##########"



curl -s \
"http://127.0.0.1:5700/api/user/init?t=$(date +%s)" \
-X PUT \
-H "Content-Type: application/json;charset=UTF-8" \
--data \
"{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}"


echo


fi







################################################
# rclone恢复
################################################


if [ -n "$RCLONE_CONF" ]

then


echo "########## rclone恢复 ##########"



if rclone ls "$REMOTE_FOLDER" >/dev/null 2>&1

then


mkdir -p "$QL_DIR/.tmp/data"



rclone sync \
"$REMOTE_FOLDER" \
"$QL_DIR/.tmp/data"



echo "✔ 数据恢复完成"


else


echo "⚠️ rclone不可用"


fi


fi






################################################
# notify
################################################


if [ -n "$NOTIFY_CONFIG" ]

then


echo "########## 通知 ##########"


python /notify.py || true


else


echo "没有通知配置"


fi







################################################
# code-server
################################################


echo "########## 启动 code-server ##########"



CODE_HOME=/home/qinglong



mkdir -p \
"$CODE_HOME/.config/code-server"



cat > "$CODE_HOME/.config/code-server/config.yaml" <<EOF

bind-addr: 0.0.0.0:10001
auth: none
disable-telemetry: true

EOF




echo "启动 code-server"



# 重点：
# 不让 Render PORT=10000 影响 code-server

PORT=10001 \
code-server \
--config "$CODE_HOME/.config/code-server/config.yaml" \
>/tmp/code-server.log 2>&1 &



echo "code-server PID=$!"



sleep 5



echo "########## code-server日志 ##########"


cat /tmp/code-server.log || true







################################################
# 端口检测
################################################


echo "########## 端口检测 ##########"



ss -lntp | grep -E "5700|10000|10001" || true



echo "================================"

echo "青龙主程序运行完成"

echo "================================"





################################################
# 保持运行
################################################


tail -f /dev/null

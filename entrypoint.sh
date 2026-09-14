#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-09-15-QINGLONG-2.21.0-DEBIAN-RENDER-FINAL-V7 🔥🔥🔥"


set -e


export PATH="$HOME/bin:$PATH"



################################################
# 基础变量
################################################

QL_DIR=${QL_DIR:-/ql}

dir_shell="$QL_DIR/shell"


echo "HOME=$HOME"
echo "USER=$(whoami)"




################################################
# 加载青龙环境
################################################

if [ -f "$dir_shell/share.sh" ]; then

    . "$dir_shell/share.sh"

else

    echo "⚠️ share.sh 不存在"

fi



if [ -f "$dir_shell/env.sh" ]; then


    load_ql_envs || true


    export BACK_PORT="${ql_port}"
    export GRPC_PORT="${ql_grpc_port}"


    . "$dir_shell/env.sh"


    import_config "$@" || true


    fix_config || true


fi





################################################
# rclone配置
################################################


echo
echo "======================写入 rclone 配置========================"



if [ -n "$RCLONE_CONF" ]; then


    mkdir -p "$HOME/.config/rclone"


    echo "$RCLONE_CONF" \
    > "$HOME/.config/rclone/rclone.conf"



    chmod 600 "$HOME/.config/rclone/rclone.conf"



    echo "✔ rclone 配置完成"


else


    echo "没有检测到 RCLONE_CONF"


fi






################################################
# Render PORT
################################################


echo

echo "Render PORT=$PORT"



if [ -z "$PORT" ]; then

    echo "❌ Render PORT不存在"

    exit 1

fi






################################################
# 固定青龙端口
################################################


if [ -f "$QL_DIR/.env" ]; then


    sed -i \
    "s/^PORT=.*/PORT=5700/" \
    "$QL_DIR/.env"



    echo "✔ 青龙固定端口5700"



fi





################################################
# 启动PM2
################################################


echo

echo "[INFO] 启动 PM2"



reload_pm2





################################################
# 等待青龙
################################################


echo "等待青龙启动..."



for i in {1..40}
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


echo

echo "======================启动 nginx========================"



if [ -f /etc/nginx/conf.d/front.conf ]; then



    envsubst '$PORT' \
    < /etc/nginx/conf.d/front.conf \
    > /tmp/front.conf



    mv \
    /tmp/front.conf \
    /etc/nginx/conf.d/front.conf



    echo "✔ nginx PORT替换完成"



fi




nginx -t



nginx -s reload 2>/dev/null || nginx



echo "✔ nginx启动完成"







################################################
# 管理员初始化
################################################


sleep 5



if [ -n "$ADMIN_USERNAME" ] && \
   [ -n "$ADMIN_PASSWORD" ]

then


echo

echo "########## 初始化管理员 ##########"



curl -s \
"http://127.0.0.1:5700/api/user/init?t=$(date +%s)" \
-X PUT \
-H "Content-Type: application/json;charset=UTF-8" \
--data \
"{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}" \
| jq



fi







################################################
# rclone恢复
################################################


if [ -n "$RCLONE_CONF" ]; then


echo

echo "########## rclone恢复 ##########"



if rclone ls "$REMOTE_FOLDER" >/dev/null 2>&1

then



mkdir -p "$QL_DIR/.tmp/data"



COUNT=$(rclone ls "$REMOTE_FOLDER" | wc -l)



if [ "$COUNT" -gt 0 ]

then



rclone sync \
"$REMOTE_FOLDER" \
"$QL_DIR/.tmp/data"



real_time=true ql reload data



echo "✔ 数据恢复完成"



else


echo "首次安装，没有备份"



fi



else


echo "⚠️ rclone连接失败"



fi



fi








################################################
# notify
################################################


if [ -n "$NOTIFY_CONFIG" ]; then


echo

echo "########## 通知 ##########"



python /notify.py || true



sleep 10



source "$QL_DIR/shell/api.sh"



notify_api \
"青龙服务启动通知" \
"青龙面板成功启动"



else


echo "没有通知配置"



fi







################################################
# code-server
################################################


echo

echo "########## 启动 code-server ##########"



CODE_HOME="$HOME"



echo "CODE_HOME=$CODE_HOME"



mkdir -p \
"$CODE_HOME/.config/code-server" \
"$CODE_HOME/.local/share/code-server"




# 防止 Render 重启残留

pkill -f code-server || true





cat > "$CODE_HOME/.config/code-server/config.yaml" <<EOF
bind-addr: 0.0.0.0:10001
auth: none
disable-telemetry: true
EOF





echo "code-server路径:"

which code-server || true



echo "code-server版本:"

code-server --version || true





echo "启动 code-server"



nohup /usr/bin/code-server \
--config "$CODE_HOME/.config/code-server/config.yaml" \
--user-data-dir "$CODE_HOME/.local/share/code-server" \
>/tmp/code-server.log 2>&1 &



CODE_PID=$!



echo "code-server PID=$CODE_PID"



sleep 8





echo

echo "########## code-server日志 ##########"



cat /tmp/code-server.log || true






echo

echo "########## code-server进程 ##########"



ps aux | grep code-server | grep -v grep || true






echo

echo "########## 端口检测 ##########"



(ss -tlnp 2>/dev/null || true) \
| grep -E "5700|10001|$PORT" || true






################################################
# 保持容器
################################################


echo

echo "================================"

echo "青龙主程序运行完成"

echo "================================"



wait

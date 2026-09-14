#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-09-15-QINGLONG-2.21.0-DEBIAN-RENDER-FIX 🔥🔥🔥"

set -e


################################################
# 基础环境
################################################

export PATH="$HOME/bin:$PATH"

QL_DIR=${QL_DIR:-/ql}

dir_shell="${QL_DIR}/shell"


echo "HOME=$HOME"
echo "USER=$(whoami)"



################################################
# 加载青龙环境
################################################

if [ -f "$dir_shell/share.sh" ]; then
    . "$dir_shell/share.sh"
else
    echo "⚠️ share.sh不存在"
fi



export_ql_envs()
{
    export BACK_PORT="${ql_port}"
    export GRPC_PORT="${ql_grpc_port}"
}



log()
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"
}



log INFO "加载青龙环境"



if [ -f "$dir_shell/env.sh" ]; then

    load_ql_envs

    export_ql_envs

    . "$dir_shell/env.sh"

    import_config "$@"

    fix_config

fi



################################################
# rclone 配置
################################################

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

echo "Render PORT=$PORT"



if [ -n "$PORT" ] && [ -f "$QL_DIR/.env" ]; then


    sed -i \
    "s/^PORT=.*/PORT=$PORT/" \
    "$QL_DIR/.env"


    echo "✔ 青龙 PORT 修改完成"


fi




################################################
# 启动 PM2 青龙
################################################


log INFO "启动 PM2"


reload_pm2



################################################
# bot
################################################


if [[ "$AutoStartBot" == "true" ]]; then


    echo "启动 bot"


    nohup ql bot \
    > "$dir_log/bot.log" 2>&1 &


fi



################################################
# extra
################################################


if [[ "$EnableExtraShell" == "true" ]]; then


    echo "启动 extra"


    nohup ql extra \
    > "$dir_log/extra.log" 2>&1 &


fi



################################################
# 等待青龙
################################################


echo "等待青龙服务启动..."


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



if command -v envsubst >/dev/null 2>&1; then


    if [ -f /etc/nginx/conf.d/front.conf ]; then


        envsubst '$PORT' \
        < /etc/nginx/conf.d/front.conf \
        > /tmp/front.conf


        mv /tmp/front.conf \
        /etc/nginx/conf.d/front.conf


        echo "✔ nginx PORT 替换完成"


    fi


fi



nginx -t


if nginx -s reload 2>/dev/null

then

    echo "✔ nginx reload"

else

    nginx

    echo "✔ nginx start"

fi




################################################
# 初始化管理员
################################################


sleep 5



if [ -n "$ADMIN_USERNAME" ] && \
   [ -n "$ADMIN_PASSWORD" ]

then


echo "########## 初始化管理员 ##########"



API=$(curl -s \
"http://127.0.0.1:5700/api/user/init?t=$(date +%s)" \
-X PUT \
-H "Content-Type: application/json;charset=UTF-8" \
--data "{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}")



CODE=$(echo "$API" | jq -r .code)



if [ "$CODE" = "200" ]

then

    echo "✔ 管理员初始化成功"

else

    echo "$API"

fi


fi




################################################
# rclone 恢复
################################################


if [ -n "$RCLONE_CONF" ]; then


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

        echo "首次安装，无备份"


    fi


else

    echo "⚠ rclone remote不可用"


fi


fi




################################################
# notify
################################################


if [ -n "$NOTIFY_CONFIG" ]; then


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


echo "########## 启动 code-server ##########"



CODE_HOME="$HOME"


echo "CODE_HOME=$CODE_HOME"



mkdir -p \
"$CODE_HOME/.config/code-server" \
"$CODE_HOME/.local/share/code-server"



echo "code-server路径:"


which code-server || true



echo "code-server版本:"


code-server --version || true




echo "启动 code-server"



nohup /usr/bin/code-server \
--bind-addr 0.0.0.0:10001 \
--auth none \
--disable-telemetry \
--user-data-dir "$CODE_HOME/.local/share/code-server" \
>/tmp/code-server.log 2>&1 &



CODE_PID=$!



echo "code-server PID=$CODE_PID"



sleep 8



echo "########## code-server日志 ##########"



cat /tmp/code-server.log || true



echo "########## code-server进程 ##########"



ps aux | grep code-server | grep -v grep || true



echo "########## 端口检测 ##########"



(ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || true) | grep 10001 || true




################################################
# 保活
################################################


echo "青龙主程序运行完成"



pm2 logs \
>/ql/data/pm2.log 2>&1 &



tail -f /ql/data/pm2.log

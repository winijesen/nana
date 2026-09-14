#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: 2026-09-15-QINGLONG-2.21.0-DEBIAN 🔥🔥🔥"


set -e


export PATH="$HOME/bin:$PATH"


QL_DIR=${QL_DIR:-/ql}
dir_shell=${QL_DIR}/shell


if [ -f "$dir_shell/share.sh" ]; then
    . "$dir_shell/share.sh"
else
    echo "⚠️ 未找到 share.sh"
fi



################################################
# HOME 兼容
################################################

USER_HOME=${HOME:-/home/coder}

echo "HOME=$USER_HOME"



################################################
# rclone 配置
################################################

echo "======================写入 rclone 配置========================"


if [ -n "$RCLONE_CONF" ]; then

    mkdir -p "$USER_HOME/.config/rclone"

    echo "$RCLONE_CONF" \
    > "$USER_HOME/.config/rclone/rclone.conf"


    chmod 600 "$USER_HOME/.config/rclone/rclone.conf"


    echo "✔ rclone 配置完成"

else

    echo "没有检测到 RCLONE_CONF"

fi



################################################
# 环境加载
################################################

export_ql_envs()
{
    export BACK_PORT="${ql_port}"
    export GRPC_PORT="${ql_grpc_port}"
}



log_with_style()
{
    local level="$1"
    local message="$2"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    printf "\n[%s] [%7s] %s\n" \
    "$timestamp" \
    "$level" \
    "$message"
}



log_with_style INFO "🚀 加载青龙环境"


if [ -f "$dir_shell/env.sh" ]; then

    load_ql_envs

    export_ql_envs

    . "$dir_shell/env.sh"

    import_config "$@"

    fix_config

fi



################################################
# Render PORT
################################################

echo "Render PORT=$PORT"


if [ -z "$PORT" ]; then

    echo "⚠️ PORT为空"

else

    echo "✔ PORT=$PORT"

fi



################################################
# 修改青龙端口
################################################


if [ -f "$QL_DIR/.env" ] && [ -n "$PORT" ]; then


    sed -i \
    "s/^PORT=.*/PORT=$PORT/" \
    "$QL_DIR/.env"


    echo "✔ 青龙 PORT 修改完成"

fi



################################################
# PM2
################################################


log_with_style INFO "启动 PM2"


pm2 ls >/dev/null 2>&1 || true


reload_pm2



################################################
# bot
################################################


if [[ "$AutoStartBot" == "true" ]]; then


    log_with_style INFO "启动 bot"


    nohup ql bot \
    > "$dir_log/bot.log" 2>&1 &


fi



################################################
# extra
################################################


if [[ "$EnableExtraShell" == "true" ]]; then


    log_with_style INFO "执行 extra"


    nohup ql extra \
    > "$dir_log/extra.log" 2>&1 &


fi



################################################
# 等待青龙启动
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
        > /etc/nginx/conf.d/front_render.conf


        mv \
        /etc/nginx/conf.d/front_render.conf \
        /etc/nginx/conf.d/front.conf


        echo "✔ nginx PORT 替换完成"


    fi


fi



nginx -t


if nginx -s reload 2>/dev/null
then

    echo "✔ nginx reload"

else

    nginx -c /etc/nginx/nginx.conf

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
--data "{\"username\":\"$ADMIN_USERNAME\",\"password\":\"$ADMIN_PASSWORD\"}"
)



CODE=$(echo "$API" | jq -r .code)



if [ "$CODE" = "200" ]
then

    echo "✔ 管理员初始化成功"

else

    echo "⚠️ 管理员初始化返回:"
    echo "$API"

fi


fi



################################################
# rclone 恢复
################################################


if [ -n "$RCLONE_CONF" ]; then


echo "########## rclone 恢复 ##########"



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

    echo "⚠️ rclone remote 不可用"

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



CODE_HOME=${HOME:-/home/coder}



mkdir -p \
"$CODE_HOME/.config/code-server"



cat > "$CODE_HOME/.config/code-server/config.yaml" <<EOF
bind-addr: 0.0.0.0:10001
auth: none
EOF



code-server \
--config "$CODE_HOME/.config/code-server/config.yaml" \
>/tmp/code-server.log 2>&1 &



sleep 3



echo "code-server:"
cat /tmp/code-server.log || true



################################################
# 保持 PM2 日志
################################################


echo "青龙启动完成"


pm2 logs \
>/ql/data/pm2.log 2>&1 &



wait

#!/bin/bash

echo "🔥🔥🔥 ENTRYPOINT VERSION: MASTER-EXTENDED 🔥🔥🔥"

export PATH="$HOME/bin:$PATH"

dir_shell=/ql/shell
. $dir_shell/share.sh

echo "======================写入 rclone 配置========================"
mkdir -p /root/.config/rclone
echo "$RCLONE_CONF" > /root/.config/rclone/rclone.conf

load_ql_envs
export BACK_PORT="${ql_port}"
export GRPC_PORT="${ql_grpc_port}"

echo "Render PORT = $PORT"
if [ -z "$PORT" ]; then
  echo "❌ Render 未注入 PORT"
else
  echo "✔ Render 注入 PORT = $PORT"
fi

# 修改青龙监听端口
if [ -f "$QL_DIR/.env" ]; then
  sed -i "s/^PORT=.*/PORT=$PORT/" "$QL_DIR/.env"
  echo "✔ 已将青龙监听端口改为：$PORT"
fi

echo "⚙️ 启动 pm2 服务..."
reload_pm2

# 杀掉青龙自带 code-server
(
  sleep 5
  echo ">>> KILLING BUILT-IN CODE-SERVER <<<"
  pkill -f "code-server"
) &

echo "======================启动 nginx========================"
envsubst '$PORT' < /etc/nginx/conf.d/front.conf > /etc/nginx/conf.d/front_render.conf
mv /etc/nginx/conf.d/front_render.conf /etc/nginx/conf.d/front.conf
nginx -s reload 2>/dev/null || nginx -c /etc/nginx/nginx.conf

echo "======================启动 code-server========================"
rm -rf /root/.config/code-server
mkdir -p /root/.config/code-server

cat > /root/.config/code-server/config.yaml <<EOF
bind-addr: 0.0.0.0:10001
auth: password
password: ${ADMIN_PASSWORD}
EOF

echo ">>> RUNNING CODE-SERVER <<<"
code-server --config /root/.config/code-server/config.yaml > /tmp/code-server.log 2>&1 &
sleep 2
echo ">>> CODE-SERVER EXIT CODE: $? <<<"
echo ">>> CODE-SERVER LOG CONTENT <<<"
cat /tmp/code-server.log || true

echo "======================青龙主程序已启动========================"

# 保持容器运行（前台阻塞）
pm2 logs

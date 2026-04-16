FROM whyour/qinglong:latest

# 安装 code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# 安装 nginx
RUN apt update && apt install -y nginx

# 安装 rclone
RUN curl https://rclone.org/install.sh | bash

# 拷贝 nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf
COPY front.conf /etc/nginx/conf.d/front.conf

# 拷贝 entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["bash", "/usr/local/bin/entrypoint.sh"]

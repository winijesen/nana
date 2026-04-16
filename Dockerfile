FROM whyour/qinglong:latest

# 安装必要工具
RUN apt update && apt install -y curl wget gnupg ca-certificates

# 安装 code-server（使用 .deb 包，不用 install.sh）
RUN wget https://github.com/coder/code-server/releases/download/v4.89.1/code-server_4.89.1_amd64.deb \
    && dpkg -i code-server_4.89.1_amd64.deb || apt --fix-broken -y install \
    && rm code-server_4.89.1_amd64.deb

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

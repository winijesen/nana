FROM whyour/qinglong:latest

# 安装必要依赖（Alpine 环境）
RUN apk update && apk add --no-cache \
    bash \
    curl \
    wget \
    nginx \
    libc6-compat \
    ca-certificates \
    coreutils \
    unzip

# 安装 code-server（使用官方 tar.gz，适配 Linux x86_64）
RUN wget https://github.com/coder/code-server/releases/download/v4.89.1/code-server-4.89.1-linux-amd64.tar.gz \
    && tar -xzf code-server-4.89.1-linux-amd64.tar.gz \
    && mv code-server-4.89.1-linux-amd64 /usr/lib/code-server \
    && ln -s /usr/lib/code-server/bin/code-server /usr/bin/code-server \
    && rm code-server-4.89.1-linux-amd64.tar.gz

# 安装 rclone（官方安装脚本，兼容 Alpine）
RUN curl https://rclone.org/install.sh | bash

# 拷贝 nginx 配置
COPY nginx.conf /etc/nginx/nginx.conf
COPY front.conf /etc/nginx/conf.d/front.conf

# 拷贝入口脚本
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

FROM ghcr.io/whyour/qinglong:2.21.0-debian


LABEL maintainer="whyour"


USER root


# =====================================
# 安装扩展组件
# nginx
# rclone
# gettext-base(envsubst)
# =====================================

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    nginx \
    rclone \
    gettext-base \
    jq \
    curl \
    wget \
    git \
    openssh-client \
    tzdata \
    procps \
    unzip \
    ca-certificates \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*



# =====================================
# 安装 code-server
# =====================================

RUN curl -fsSL https://code-server.dev/install.sh | \
    sh -s -- --version=4.96.4



# =====================================
# nginx 配置
# =====================================

RUN rm -f /etc/nginx/conf.d/default.conf && \
    rm -f /etc/nginx/sites-enabled/default


COPY nginx.conf /etc/nginx/nginx.conf

COPY front.conf /etc/nginx/conf.d/front.conf



# =====================================
# 通知脚本
# =====================================

COPY notify.py /notify.py

RUN chmod 755 /notify.py



# =====================================
# 自定义启动脚本
# 注意：
# GitHub 文件名是 entrypoint.sh
# =====================================

COPY entrypoint.sh /usr/local/bin/docker-entrypoint.sh

RUN chmod +x /usr/local/bin/docker-entrypoint.sh



# =====================================
# 时区
# =====================================

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" >/etc/timezone



# =====================================
# Git 配置
# =====================================

RUN git config --global user.email "qinglong@users.noreply.github.com" && \
    git config --global user.name "qinglong"



# =====================================
# 工作目录
# =====================================

WORKDIR /ql



# =====================================
# 启动
# =====================================

USER root


ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]



EXPOSE 80


VOLUME ["/ql/data"]

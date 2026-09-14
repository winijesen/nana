FROM ghcr.io/whyour/qinglong:2.21.0-debian


LABEL maintainer="winijesen"


USER root



# ==================================================
# 安装扩展组件
# nginx
# rclone
# envsubst
# jq
# 网络工具
# ==================================================

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
    net-tools \
    iproute2 \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*



# ==================================================
# nginx 配置
# ==================================================

RUN rm -f /etc/nginx/conf.d/default.conf && \
    rm -f /etc/nginx/sites-enabled/default && \
    mkdir -p /var/log/nginx



COPY front.conf /etc/nginx/conf.d/front.conf



# ==================================================
# 通知脚本
# ==================================================

COPY notify.py /notify.py


RUN chmod 755 /notify.py



# ==================================================
# 自定义启动入口
# ==================================================

COPY entrypoint.sh /usr/local/bin/entrypoint.sh


RUN chmod 755 /usr/local/bin/entrypoint.sh



# ==================================================
# 时区
# ==================================================

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone



# ==================================================
# 工作目录
# ==================================================

WORKDIR /ql



# ==================================================
# 保持 root
# QingLong PM2 + nginx 需要
# ==================================================

USER root



# ==================================================
# Render
# 实际端口由 nginx 使用环境变量 PORT
# EXPOSE 只是说明
# ==================================================

EXPOSE 10000



# ==================================================
# 数据目录
# ==================================================

VOLUME ["/ql/data"]



# ==================================================
# 启动
# ==================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

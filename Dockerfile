FROM ghcr.io/whyour/qinglong:2.21.0-debian


LABEL maintainer="winijesen"


USER root



# ==================================================
# 安装扩展组件
# nginx
# sshpass
# envsubst
# jq
# 网络工具
# ==================================================

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
    nginx \
    sshpass \
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
# 安装最新版 rclone
# 官方安装脚本
# 自动下载 + 解压 + 安装
# ==================================================

RUN curl https://rclone.org/install.sh | bash && \
    rclone version && \
    sshpass -V



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
# 实际监听由 nginx 使用 $PORT
# EXPOSE 不决定 Render 端口
# ==================================================

EXPOSE 80



# ==================================================
# 数据目录
# ==================================================

VOLUME ["/ql/data"]



# ==================================================
# 启动
# ==================================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

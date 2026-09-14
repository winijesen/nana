FROM ghcr.io/whyour/qinglong:2.21.0-debian


LABEL maintainer="winijesen"


USER root



# =====================================
# 安装扩展组件
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
    net-tools \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*



# =====================================
# 安装 code-server
# =====================================

RUN curl -fsSL https://code-server.dev/install.sh | \
    sh -s -- --version=4.96.4



# =====================================
# nginx
# =====================================

RUN rm -f /etc/nginx/conf.d/default.conf && \
    rm -f /etc/nginx/sites-enabled/default


COPY front.conf /etc/nginx/conf.d/front.conf



# =====================================
# notify
# =====================================

COPY notify.py /notify.py

RUN chmod 755 /notify.py



# =====================================
# entrypoint
# =====================================

COPY entrypoint.sh /usr/local/bin/entrypoint.sh


RUN chmod +x /usr/local/bin/entrypoint.sh



# =====================================
# 时区
# =====================================

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" >/etc/timezone



WORKDIR /ql



# =====================================
# 启动
# =====================================

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]



EXPOSE 80


VOLUME ["/ql/data"]

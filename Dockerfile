FROM btpanel/baota:nas

# 安装 Gitea 1.21 二进制版 :cite[1]
RUN set -eux; \
    adduser --system --shell /bin/bash --gecos 'Git Version Control' --group --disabled-password --home /home/git git; \
    mkdir -p /www/gitea/{custom,data,indexers,public,log}; \
    mkdir -p /etc/gitea; \
    chown -R git:git /www/gitea /etc/gitea; \
    chmod -R 750 /www/gitea; \
    chmod 770 /etc/gitea; \
    wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/1.21.11/gitea-1.21.11-linux-amd64; \
    chmod +x /usr/local/bin/gitea

FROM btpanel/baota:nas

# 安装 Gitea 1.21 二进制版 :cite[1]
RUN set -eux; \
    # 创建gitea用户和组 :cite[1]
    adduser --system --shell /bin/bash --gecos 'Git Version Control' --group --disabled-password --home /home/git git; \
    # 创建工作目录 :cite[1]
    mkdir -p /var/lib/gitea/{custom,data,indexers,public,log}; \
    mkdir -p /etc/gitea; \
    chown -R git:git /var/lib/gitea /etc/gitea; \
    chmod -R 750 /var/lib/gitea; \
    chmod 770 /etc/gitea; \
    # 下载Gitea 1.21.8二进制文件（版本可调整）:cite[1]
    wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/1.21.8/gitea-1.21.8-linux-amd64; \
    chmod +x /usr/local/bin/gitea

# 暴露特定端口（增加Gitea的3000端口）
EXPOSE 3000

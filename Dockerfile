FROM debian:bookworm-slim

# 切换 Debian 镜像源为腾讯云源，更新包列表并安装依赖
RUN set -eux; \
    sed -i 's/deb.debian.org/mirrors.tencent.com/g' /etc/apt/sources.list.d/debian.sources || true; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://mirrors.cloud.tencent.com/docker-ce/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.cloud.tencent.com/docker-ce/linux/debian/ ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
      locales wget iproute2 openssh-server cmake make gcc g++ autoconf sudo curl dos2unix build-essential libonig-dev libxml2-dev libxslt-dev \
      docker-ce-cli; \
    sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen; \
    locale-gen en_US.UTF-8; \
    update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# 设置全局环境变量
ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# 复制脚本，设置环境变量
COPY ["bt.sh", "init_mysql.sh", "/"]

# 转换启动脚本
RUN dos2unix /bt.sh && dos2unix /init_mysql.sh

# 下载并安装宝塔面板及nginx（保持原有逻辑）
RUN curl -sSO https://download.bt.cn/install/install_panel.sh \
    && echo y | bash install_panel.sh -P 8888 --ssl-disable \
    && btpip config set global.index-url https://mirrors.tencent.com/pypi/simple \
    && mkdir /lnmp \
    && curl -o /lnmp/nginx.sh https://download.bt.cn/install/3/nginx.sh \
    && bash /lnmp/nginx.sh install 1.28 \
    && rm -rf /lnmp \
    && rm -rf /www/server/nginx/src \
    && echo "docker_bt_nas" > /www/server/panel/data/o.pl \
    && echo '["memuA", "memuAsite", "memuAwp", "memuAdatabase", "memuAcontrol", "memuAfiles", "memuAlogs", "memuAxterm", "memuAcrontab", "memuAsoft", "memuAconfig", "dologin", "memu_btwaf", "memuAssl"]' > /www/server/panel/config/show_menu.json \
    && apt clean \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /www/reserve_space.pl \
    && rm -f /www/server/panel/data/iplist.txt \
    && chmod +x /bt.sh \
    && chmod +x /init_mysql.sh

# 配置宝塔面板安全入口和用户名及密码，以及SSH密码
RUN echo ${PANEL_USERNAME:-btpanel} | bt 6 \
    && echo ${PANEL_PASSWORD:-btpaneldocker} | bt 5 \
    && echo ${ADMIN_PATH:-/btpanel} > /www/server/panel/data/admin_path.pl \
    && echo "root:btpaneldocker" | chpasswd

# 打包宝塔面板，并清除www
RUN bt 2 \
    && tar -zcf /www.tar.gz /www \
    && rm -rf /www

ENTRYPOINT ["/bin/sh","-c","/bt.sh"]

# 暴露特定端口
EXPOSE 22 80 443 888 3306 8888

# 健康检查
HEALTHCHECK --interval=5s --timeout=3s CMD prot="http"; if [ -f "/www/server/panel/data/ssl.pl" ]; then prot="https"; fi; curl -k -i $prot://127.0.0.1:$(cat /www/server/panel/data/port.pl)$(cat /www/server/panel/data/admin_path.pl) | grep -E '(200|404)' || exit 1

# 安装 Gitea 1.21 二进制版 :cite[1]
RUN set -eux; \
    adduser --system --shell /bin/bash --gecos 'Git Version Control' --group --disabled-password --home /home/git git; \
    wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/1.21.11/gitea-1.21.11-linux-amd64; \
    chmod +x /usr/local/bin/gitea

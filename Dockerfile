FROM debian:bookworm-slim

# 更新包列表并安装依赖
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg; \
    mkdir -p /etc/apt/keyrings; \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian/ ${VERSION_CODENAME} stable" \
      > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
      locales wget iproute2 openssh-server cmake make gcc g++ autoconf sudo curl dos2unix build-essential libonig-dev libxml2-dev libxslt-dev \
      docker-ce-cli \
      iputils-ping dnsutils net-tools iproute2 curl wget tcpdump netcat-openbsd traceroute mtr-tiny iperf3 nmap telnet openssh-client ca-certificates \ 
      htop iotop lsof procps sysstat file tree vim nano; \
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
COPY ["baota/bt.sh", "baota/init_mysql.sh", "/"]

# 转换启动脚本
RUN dos2unix /bt.sh && dos2unix /init_mysql.sh

# 下载并安装宝塔面板及nginx（保持原有逻辑）
RUN curl -sSO https://download.bt.cn/install/install_panel.sh \
    && echo y | bash install_panel.sh -P 8888 --ssl-disable \
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
EXPOSE 22 80 443 888 3000 3306 8848 8888

# 健康检查
HEALTHCHECK --interval=5s --timeout=3s CMD prot="http"; if [ -f "/www/server/panel/data/ssl.pl" ]; then prot="https"; fi; curl -k -i $prot://127.0.0.1:$(cat /www/server/panel/data/port.pl)$(cat /www/server/panel/data/admin_path.pl) | grep -E '(200|404)' || exit 1

# 安装Gitea
RUN set -eux; \
    adduser --system --shell /bin/bash --gecos 'Git Version Control' --group --disabled-password --home /home/git git; \
    wget -O /usr/local/bin/gitea https://dl.gitea.com/gitea/1.24.6/gitea-1.24.6-linux-amd64; \
    chmod +x /usr/local/bin/gitea

# 安装SearXNG
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-dev python3-babel python3-venv python-is-python3 \
        uwsgi uwsgi-plugin-python3 \
        git build-essential libxslt-dev zlib1g-dev libffi-dev libssl-dev \
        openssl ca-certificates sudo && \
    # 创建用户和目录
    useradd --shell /bin/bash --system \
        --home-dir /usr/local/searxng \
        --comment 'Privacy-respecting metasearch engine' searxng && \
    mkdir -p /usr/local/searxng /usr/local/searxng/searxng-src /etc/searxng /etc/uwsgi/apps-available && \
    chown -R searxng:searxng /usr/local/searxng /etc/searxng && \
    # 克隆源码
    sudo -u searxng git clone https://github.com/searxng/searxng.git /usr/local/searxng/searxng-src && \
    # 构建虚拟环境并安装依赖
    sudo -u searxng python -m venv /usr/local/searxng/searx-pyenv && \
sudo -u searxng bash -c " \
    source /usr/local/searxng/searx-pyenv/bin/activate && \
    pip install -U pip setuptools wheel && \
    pip install \
        certifi==2025.10.5 \
        babel==2.17.0 \
        flask-babel==4.0.0 \
        flask==3.1.2 \
        jinja2==3.1.6 \
        lxml==6.0.2 \
        pygments==2.19.2 \
        python-dateutil==2.9.0.post0 \
        pyyaml==6.0.3 \
        \"httpx[http2]==0.28.1\" \
        \"httpx-socks[asyncio]==0.10.0\" \
        Brotli==1.1.0 \
        setproctitle==1.3.7 \
        valkey==6.1.1 \
        markdown-it-py==3.0.0 \
        fasttext-predict==0.9.2.4 \
        \"tomli==2.3.0; python_version < '3.11'\" \
        msgspec==0.19.0 \
        typer-slim==0.19.2 \
        isodate==0.7.2 \
        whitenoise==6.11.0 \
        typing-extensions==4.14.1 && \
        # 安装SearXNG editable模式
        cd /usr/local/searxng/searxng-src && \
        pip install --use-pep517 --no-build-isolation -e ." && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
# 复制配置文件
COPY settings.yml /etc/searxng/settings.yml
COPY searxng.ini /etc/uwsgi/apps-available/searxng.ini
# 设置权限并替换密钥
RUN chown searxng:searxng /etc/searxng/settings.yml /etc/uwsgi/apps-available/searxng.ini && \
    sed -i "s/ultrasecretkey/$(openssl rand -hex 16)/g" /etc/searxng/settings.yml
RUN chown searxng:searxng /etc/searxng/settings.yml /etc/uwsgi/apps-available/searxng.ini && \
    # 替换settings.yml中的密钥（如果有占位符）
    sed -i "s/ultrasecretkey/$(openssl rand -hex 16)/g" /etc/searxng/settings.yml

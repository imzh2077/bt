#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

init_path=/etc/init.d
Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/mysql
Data_Path=$Root_Path/server/data
O_pl=$(cat /www/server/panel/data/o.pl)

# 新增Gitea启动函数 :cite[1]
start_gitea() {
    echo "Starting Gitea..."
    # 等待宝塔服务完全启动
    sleep 10
    
    # 初始化Gitea配置（如果不存在）
    # if [ ! -f /etc/gitea/app.ini ]; then
    #    echo "Initializing Gitea configuration..."
    #    sudo -u git /usr/local/bin/gitea web --config /etc/gitea/app.ini &
    #    GITEA_PID=$!
    #    sleep 15
        # 关闭初始化的Gitea进程
    #    kill $GITEA_PID 2>/dev/null || true
    #    wait $GITEA_PID 2>/dev/null || true
        
        # 设置基本配置（可根据需要调整）
    #    if [ -f /etc/gitea/app.ini ]; then
    #        sed -i 's/HTTP_PORT = 3000/HTTP_PORT = 3000/g' /etc/gitea/app.ini
    #        sed -i 's/ROOT_URL = http:/ROOT_URL = http:/g' /etc/gitea/app.ini
    #        sed -i 's/SSH_PORT = 22/SSH_PORT = 2222/g' /etc/gitea/app.ini
            # 设置SQLite3为默认数据库以简化部署
    #        sed -i 's/DB_TYPE = mysql/DB_TYPE = sqlite3/g' /etc/gitea/app.ini 2>/dev/null || true
    #    fi
    #fi
    
    # 设置权限
    chown -R git:git /var/lib/gitea /etc/gitea
    chmod -R 750 /var/lib/gitea
    chmod 770 /etc/gitea
    
    # 以后台方式启动Gitea :cite[1]
    sudo -u git /usr/local/bin/gitea web --config /etc/gitea/app.ini &
    echo $! > /var/run/gitea.pid
    echo "Gitea started successfully"
}

backup_database() {
  if [ -d "${Data_Path}" ] && [ ! -z "$(ls -A ${Data_Path})" ]; then
    if [ ! -d "${Setup_Path}" ] || [ -z "$(ls -A ${Setup_Path})" ]; then
      timestamp=$(date +"%s")
      tar czf /www/server/data_backup_$timestamp.tar.gz -C ${Data_Path} .
    fi
  fi
}

restore_panel_data() {
  if [ -f /www.tar.gz ]; then
    if [ ! -d /www ] || [ -z "$(ls -A /www)" ] || [ ! -d /www/server/panel ] || [ -z "$(ls -A /www/server/panel)" ] || [ ! -d /www/server/panel/pyenv ] || [ -z "$(ls -A /www/server/panel/pyenv)" ]; then
      tar xzf /www.tar.gz -C / --skip-old-files
      rm -rf /www.tar.gz
    fi
  fi
}

soft_start(){
    # 扫描并启动所有服务
    init_scripts=$(ls ${init_path})
    for script in ${init_scripts}; do
        case "${script}" in
        "bt"|"mysqld"|"nginx"|"httpd")
            continue
            ;;
        esac

        ${init_path}/${script} start
    done

    if [ -f ${init_path}/nginx ]; then
        ${init_path}/nginx start
    elif [ -f ${init_path}/httpd ]; then
        ${init_path}/httpd start
    fi

    ${init_path}/bt stop
    ${init_path}/bt start

    pkill crond
    /sbin/crond

    chmod 600 /etc/ssh/ssh_host_*
    /usr/sbin/sshd -D &

    # 在宝塔服务启动后启动Gitea
    start_gitea
}

init_mysql(){
    if [ "${O_pl}" != "docker_btlamp_d12" ] && [ "${O_pl}" != "docker_btlnmp_d12" ];then
        return
    fi
    if [ -d "${Data_Path}" ]; then
        check_z=$(ls "${Data_Path}")
        echo "check_z:"
        echo ${check_z}
        if [[ ! -z "${check_z}" ]]; then
            echo "check_z is not empty"
            return
        fi
    fi
    if [ -f /init_mysql.sh ] && [ -d "${Setup_Path}" ];then
        bash /init_mysql.sh
        rm -f /init_mysql.sh
    fi
}

is_empty_Data(){
    return "$(ls -A ${Data_Path}/|wc -w)"
}

start_mysql(){
    if [ -d "${Setup_Path}" ] && [ -f "${init_path}/mysqld" ];then
        chown -R mysql:mysql ${Data_Path}
        chgrp -R mysql ${Setup_Path}/.
        ${init_path}/mysqld start
    fi
}

restore_panel_data > /dev/null
backup_database > /dev/null
is_empty_Data > /dev/null
init_mysql > /dev/null
start_mysql > /dev/null
soft_start > /dev/null
#tail -f /dev/null
${init_path}/bt log

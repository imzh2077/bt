#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

Root_Path=`cat /var/bt_setupPath.conf`
Setup_Path=$Root_Path/server/mysql
Data_Path=$Root_Path/server/data

Mysql_Initialize(){
    if [ -d "${Data_Path}" ]; then
        check_z=$(ls "${Data_Path}")
        if [[ ! -z "${check_z}" ]]; then
            return
        fi
    fi

    mkdir -p ${Data_Path}
    chown -R mysql:mysql ${Data_Path}
    chgrp -R mysql ${Setup_Path}/.

    ${Setup_Path}/bin/mysqld --initialize-insecure --basedir=${Setup_Path} --datadir=${Data_Path} --user=mysql

    cat > /etc/ld.so.conf.d/mysql.conf<<EOF
${Setup_Path}/lib
EOF
    ldconfig
    ln -sf ${Setup_Path}/lib/mysql /usr/lib/mysql
    ln -sf ${Setup_Path}/include/mysql /usr/include/mysql
    /etc/init.d/mysqld start

    mysqlpwd=`cat /dev/urandom | head -n 16 | md5sum | head -c 16`
    ${Setup_Path}/bin/mysqladmin -u root password "${mysqlpwd}"

    cd "${Setup_Path}"
    rm -f src.tar.gz
    rm -rf src
    /etc/init.d/mysqld start
    rm -rf /init_mysql.sh
}

Mysql_Initialize

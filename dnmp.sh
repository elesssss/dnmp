#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "amazon linux" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && echo -e "${RED}注意：请在root用户下运行脚本${NC}" && exit 1

# 检测系统类型
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i"
    [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        [[ -n $SYSTEM ]] && break
    fi
done

[[ -z $SYSTEM ]] && echo -e "${RED}不支持当前VPS系统, 请使用主流的操作系统${NC}" && exit 1

# ==================== 辅助函数 ====================
check_container_running() {
    local container=$1
    docker ps --format "table {{.Names}}" | grep -q "^${container}$"
}

ensure_container() {
    local container=$1
    if ! check_container_running "$container"; then
        echo -e "${RED}容器 ${container} 未运行，请先启动${NC}"
        return 1
    fi
    return 0
}

go_back_main() {
    echo ""
    read -rp "请输入“y”退出, 或按任意键回到主菜单：" choice
    case "$choice" in
    y) exit 1 ;;
    *) menu ;;
    esac
}

go_back_run() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" choice
    case "$choice" in
    y) menu ;;
    *) run_dnmp ;;
    esac
}

go_back_stop() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" choice
    case "$choice" in
    y) menu ;;
    *) stop_dnmp ;;
    esac
}

go_back_db() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" choice
    case "$choice" in
    y) menu ;;
    *) mg_database ;;
    esac
}

# ==================== 核心功能 ====================
install_base() {
    echo -e "${GREEN}开始安装依赖...${NC}"
    OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)    
    if [[ "$OS" == "Debian" || "$OS" == "Ubuntu" ]]; then
        commands=("git" "socat" "lsof" "cron" "ip")
        apps=("git" "socat" "lsof" "cron" "iproute2")
        install=()
        for i in "${!commands[@]}"; do
            command -v "${commands[i]}" &>/dev/null || install+=("${apps[i]}")
        done
        [[ ${#install[@]} -gt 0 ]] && apt update -y && apt install -y "${install[@]}"
        systemctl enable --now cron >/dev/null 2>&1
    elif [[ "$OS" == "CentOS" ]]; then
        commands=("git" "socat" "lsof" "crond" "ip")
        apps=("git" "socat" "lsof" "cronie" "iproute")
        install=()
        for i in "${!commands[@]}"; do
            command -v "${commands[i]}" &>/dev/null || install+=("${apps[i]}")
        done
        [[ ${#install[@]} -gt 0 ]] && yum update -y && yum install -y "${install[@]}"
        systemctl enable --now crond >/dev/null 2>&1
    else
        echo -e "${RED}很抱歉，你的系统不受支持！"
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
        systemctl enable --now docker >/dev/null 2>&1
    fi

    if ! command -v docker-compose &>/dev/null; then
        echo -e "${YELLOW}安装 docker-compose 独立二进制...${NC}"
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi

    echo -e "${GREEN}依赖安装完毕！${NC}"
}

install_dnmp() {
    install_base
    echo -e "${GREEN}开始安装 Dnmp...${NC}"
    
    if [ -d "/var/dnmp" ]; then
        echo -e "${GREEN}Dnmp 已安装。${NC}"
    else
        if git clone https://github.com/elesssss/dnmp.git /var/dnmp; then
            echo -e "${GREEN}Dnmp 安装成功。${NC}"
            # 如果存在 .env.example，则复制为 .env
            [[ -f /var/dnmp/.env.example ]] && cp /var/dnmp/.env.example /var/dnmp/.env
        else
            echo -e "${RED}Dnmp 安装失败，请检查是否能连通github。${NC}"
            go_back_main
        fi
    fi
    go_back_main
}

set_dnmp() {
    if [ ! -f /var/dnmp/.env ]; then
        echo -e "${RED}未找到 /var/dnmp/.env 文件，请先安装 Dnmp。${NC}"
        go_back_main
    fi

    read -p "设置nginx的版本（默认：latest）: " nginx_v
    nginx_v=${nginx_v:-latest}
    sed -i -e "s/NGINX_V=.*$/NGINX_V=$nginx_v/" /var/dnmp/.env

    read -p "设置mysql的root密码（默认：root123）: " mysql_password
    mysql_password=${mysql_password:-root123}
    sed -i -e "s/MYSQL_PASSWORD=.*$/MYSQL_PASSWORD=$mysql_password/" /var/dnmp/.env

    read -p "设置mariadb的root密码（默认：root123）: " mariadb_password
    mariadb_password=${mariadb_password:-root123}
    sed -i -e "s/MARIADB_PASSWORD=.*$/MARIADB_PASSWORD=$mariadb_password/" /var/dnmp/.env

    read -p "设置redis的密码（默认：root123）: " redis_password
    redis_password=${redis_password:-root123}
    sed -i -e "s/REDIS_PASSWORD=.*$/REDIS_PASSWORD=$redis_password/" /var/dnmp/.env

    echo "设置的信息如下"
    echo -e "${GREEN}nginx${NC}的版本：${GREEN}$nginx_v${NC}"
    echo -e "${GREEN}mysql${NC}的root密码：${GREEN}$mysql_password${NC}"
    echo -e "${GREEN}mariadb${NC}的root密码：${GREEN}$mariadb_password${NC}"
    echo -e "${GREEN}redis${NC}的密码：${GREEN}$redis_password${NC}"
    go_back_main
}

creat_mysql() {
    ensure_container mysql || { go_back_db; return; }
    read -rp "请输入要新建的mysql数据库名：" mysql_name
    [[ -z $mysql_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && go_back_db
    read -rp "请输入mysql的root密码：" mysql_password
    [[ -z $mysql_password ]] && echo -e "${RED}未输入mysql的root密码，无法执行操作！${NC}" && go_back_db

    docker exec mysql mysql -uroot -p"${mysql_password}" -e "create database ${mysql_name} default character set utf8mb4 collate utf8mb4_unicode_ci;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${mysql_name}${NC}创建${GREEN}成功!${NC}"
    else
        echo -e "${RED}密码错误或连接失败，无法创建数据库！${NC}"
    fi
    go_back_db
}

creat_mariadb() {
    ensure_container mariadb || { go_back_db; return; }
    read -rp "请输入要新建的mariadb数据库名：" mariadb_name
    [[ -z $mariadb_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && go_back_db
    read -rp "请输入mariadb的root密码：" mariadb_password
    [[ -z $mariadb_password ]] && echo -e "${RED}未输入mariadb的root密码，无法执行操作！${NC}" && go_back_db

    docker exec mariadb mariadb -uroot -p"${mariadb_password}" -e "create database ${mariadb_name} default character set utf8mb4 collate utf8mb4_unicode_ci;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${mariadb_name}${NC}创建${GREEN}成功!${NC}"
    else
        echo -e "${RED}密码错误或连接失败，无法创建数据库！${NC}"
    fi
    go_back_db
}

backup_mysql() {
    ensure_container mysql || { go_back_db; return; }
    read -rp "请输入要备份的mysql数据库名：" mysql_name
    [[ -z $mysql_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && go_back_db
    read -rp "请输入mysql的root密码：" mysql_password
    [[ -z $mysql_password ]] && echo -e "${RED}未输入mysql的root密码，无法执行操作！${NC}" && go_back_db

    DATE=$(date +%Y%m%d_%H%M%S)
    LOCK="--skip-lock-tables"

    docker exec mysql bash -c "mysqldump -uroot -p${mysql_password} ${LOCK} --default-character-set=utf8 --flush-logs -R ${mysql_name} > /var/lib/mysql/${mysql_name}_${DATE}.sql" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        cd /var/dnmp/mysql && tar zcpvf "/root/${mysql_name}_${DATE}.sql.tar.gz" "${mysql_name}_${DATE}.sql" >/dev/null 2>&1 && rm -f "${mysql_name}_${DATE}.sql"
        echo -e "数据库${GREEN}${mysql_name}${NC}备份${GREEN}成功${NC}，备份文件${GREEN}${mysql_name}_${DATE}.sql.tar.gz${NC}在${GREEN}/root/${NC}目录下"
    else
        echo -e "${RED}数据库${mysql_name}备份失败，请检查root密码或数据库名是否正确！${NC}"
    fi
    go_back_db
}

backup_mariadb() {
    ensure_container mariadb || { go_back_db; return; }
    read -rp "请输入要备份的mariadb数据库名：" mariadb_name
    [[ -z $mariadb_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && go_back_db
    read -rp "请输入mariadb的root密码：" mariadb_password
    [[ -z $mariadb_password ]] && echo -e "${RED}未输入mariadb的root密码，无法执行操作！${NC}" && go_back_db

    DATE=$(date +%Y%m%d_%H%M%S)
    LOCK="--skip-lock-tables"

    docker exec mariadb bash -c "mariadb-dump -uroot -p${mariadb_password} ${LOCK} --default-character-set=utf8 --flush-logs -R ${mariadb_name} > /var/lib/mysql/${mariadb_name}_${DATE}.sql" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        cd /var/dnmp/mariadb && tar zcpvf "/root/${mariadb_name}_${DATE}.sql.tar.gz" "${mariadb_name}_${DATE}.sql" >/dev/null 2>&1 && rm -f "${mariadb_name}_${DATE}.sql"
        echo -e "数据库${GREEN}${mariadb_name}${NC}备份${GREEN}成功${NC}，备份文件${GREEN}${mariadb_name}_${DATE}.sql.tar.gz${NC}在${GREEN}/root/${NC}目录下"
    else
        echo -e "${RED}数据库${mariadb_name}备份失败，请检查root密码或数据库名是否正确！${NC}"
    fi
    go_back_db
}

del_mysql() {
    ensure_container mysql || { go_back_db; return; }
    read -rp "请输入要删除的mysql数据库名：" mysql_name
    [[ -z $mysql_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && go_back_db
    read -rp "请输入mysql的root密码：" mysql_password
    [[ -z $mysql_password ]] && echo -e "${RED}未输入mysql的root密码，无法执行操作！${NC}" && go_back_db

    read -rp "确认删除数据库 ${mysql_name} ？(y/N) " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && go_back_db

    docker exec mysql mysql -uroot -p"${mysql_password}" -e "drop database ${mysql_name};" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${mysql_name}${NC}删除${GREEN}成功!${NC}"
    else
        echo -e "${RED}数据库${mysql_name}删除失败，请检查root密码或数据库名是否正确！${NC}"
    fi
    go_back_db
}

del_mariadb() {
    ensure_container mariadb || { go_back_db; return; }
    read -rp "请输入要删除的mariadb数据库名：" mariadb_name
    [[ -z $mariadb_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && go_back_db
    read -rp "请输入mariadb的root密码：" mariadb_password
    [[ -z $mariadb_password ]] && echo -e "${RED}未输入mariadb的root密码，无法执行操作！${NC}" && go_back_db

    read -rp "确认删除数据库 ${mariadb_name} ？(y/N) " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && go_back_db

    docker exec mariadb mariadb -uroot -p"${mariadb_password}" -e "drop database ${mariadb_name};" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${mariadb_name}${NC}删除${GREEN}成功!${NC}"
    else
        echo -e "${RED}数据库${mariadb_name}删除失败，请检查root密码或数据库名是否正确！${NC}"
    fi
    go_back_db
}

uninstall_dnmp() {
    echo -e " ${RED}注意！！！卸载前请先备份 Dnmp 目录${NC}"
    read -p "是否需要备份 Dnmp 目录？([Y]/n 默认备份): " backup_confirm
    if [[ -z "$backup_confirm" || "$backup_confirm" == [yY] ]]; then
        cd /var && tar zcpvf /root/dnmp.tar.gz dnmp 2>/dev/null
        echo -e "${GREEN}Dnmp 目录已备份到 /root/dnmp.tar.gz${NC}"
    fi

    read -p "确认卸载 Dnmp 吗？(y/[N] 默认不卸载): " confirm
    if [[ "$confirm" == [yY] ]]; then
        cd /var/dnmp && docker-compose down -v 2>/dev/null
        docker rm -f nginx php7.4 php8.4 php8.5 mysql mariadb redis 2>/dev/null
        docker network prune -f 2>/dev/null
        rm -rf /var/dnmp
        echo -e "${GREEN}Dnmp 已彻底卸载!${NC}"
    else
        echo -e "${YELLOW}取消卸载操作.${NC}"
    fi
    go_back_main
}

run_dnmp() {
    clear
    echo "请选择你要启动的服务"
    echo ""
    echo -e "${GREEN}1.${NC} 启动${GREEN}nginx${NC}"
    echo -e "${GREEN}2.${NC} 启动${GREEN}php7.4${NC}"
    echo -e "${GREEN}3.${NC} 启动${GREEN}php8.4${NC}"
    echo -e "${GREEN}4.${NC} 启动${GREEN}php8.5${NC}"
    echo -e "${GREEN}5.${NC} 启动${GREEN}mysql${NC}"
    echo -e "${GREEN}6.${NC} 启动${GREEN}mariadb${NC}"
    echo -e "${GREEN}7.${NC} 启动${GREEN}redis${NC}"
    echo "0. 返回主菜单"
    echo ""
    read -p "请输入选项 [0-7 用空格分开]: " -a options

    services=""
    for option in "${options[@]}"; do
        if [[ "$option" =~ ^[0-7]$ ]]; then
            case $option in
            1) services+="nginx " ;;
            2) services+="php7.4 " ;;
            3) services+="php8.4 " ;;
            4) services+="php8.5 " ;;
            5) services+="mysql " ;;
            6) services+="mariadb " ;;
            7) services+="redis " ;;
            esac
        else
            menu
        fi
    done

    if [[ -n $services ]]; then
        cd /var/dnmp && docker-compose up -d $services
        go_back_run
    fi
}

stop_dnmp() {
    clear
    echo "请选择您想要停止的服务"
    echo -e "${YELLOW}注意！！！停止mysql、mariadb和redis将清除这3个服务的数据${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} ${RED}停止nginx${NC}"
    echo -e "${GREEN}2.${NC} ${RED}停止php7.4${NC}"
    echo -e "${GREEN}3.${NC} ${RED}停止php8.4${NC}"
    echo -e "${GREEN}4.${NC} ${RED}停止php8.5${NC}"
    echo -e "${GREEN}5.${NC} ${RED}停止mysql${NC}"
    echo -e "${GREEN}6.${NC} ${RED}停止mariadb${NC}"
    echo -e "${GREEN}7.${NC} ${RED}停止redis${NC}"
    echo "0. 返回主菜单"
    echo ""
    read -rp "请输入选项[0-7 用空格分开]: " services
    for service in $services; do
        case $service in
        1) docker stop nginx && docker rm nginx ;;
        2) docker stop php7.4 && docker rm php7.4 ;;
        3) docker stop php8.4 && docker rm php8.4 ;;
        4) docker stop php8.5 && docker rm php8.5 ;;
        5) 
            read -rp "停止 mysql 将删除所有数据，确认？(y/N) " confirm
            [[ $confirm == [yY] ]] && docker stop mysql && docker rm mysql && rm -rf /var/dnmp/mysql
            ;;
        6)
            read -rp "停止 mariadb 将删除所有数据，确认？(y/N) " confirm
            [[ $confirm == [yY] ]] && docker stop mariadb && docker rm mariadb && rm -rf /var/dnmp/mariadb
            ;;
        7)
            read -rp "停止 redis 将删除所有数据，确认？(y/N) " confirm
            [[ $confirm == [yY] ]] && docker stop redis && docker rm redis && rm -rf /var/dnmp/redis
            ;;
        esac
    done
    go_back_stop
}

mg_database() {
    clear
    echo " 请选择你要进行的操作"
    echo ""
    echo " -----------------"
    echo -e " ${GREEN}1.${NC} 新建mysql数据库"
    echo -e " ${GREEN}2.${NC} 备份mysql数据库"
    echo -e " ${GREEN}3.${NC} ${RED}删除mysql数据库${NC}"
    echo " -----------------"
    echo -e " ${GREEN}4.${NC} 新建mariadb数据库"
    echo -e " ${GREEN}5.${NC} 备份mariadb数据库"
    echo -e " ${GREEN}6.${NC} ${RED}删除mariadb数据库${NC}"
    echo " 0. 返回主菜单"
    echo ""
    read -rp "请输入选项 [0-6]: " db_choice
    case $db_choice in
    1) creat_mysql ;;
    2) backup_mysql ;;
    3) del_mysql ;;
    4) creat_mariadb ;;
    5) backup_mariadb ;;
    6) del_mariadb ;;
    *) menu ;;
    esac
    go_back_db
}

menu() {
    clear
    echo "#############################################################"
    echo -e "#                     ${RED}Dnmp堆栈一键脚本${NC}                      #"
    echo -e "#                     ${GREEN}作者${NC}: 你挺能闹啊🍏                    #"
    echo "#############################################################"
    echo ""
    echo " -----------------"
    echo -e " ${GREEN}1.${NC} ${GREEN}安装 Dnmp 堆栈${NC}"
    echo -e " ${GREEN}2.${NC} ${RED}卸载 Dnmp 堆栈${NC}"
    echo " -----------------"
    echo -e " ${GREEN}3.${NC} 设置 Dnmp 参数"
    echo -e " ${GREEN}4.${NC} ${GREEN}启动 Dnmp 服务${NC}"
    echo -e " ${GREEN}5.${NC} ${RED}停止 Dnmp 服务${NC}"
    echo " -----------------"
    echo -e " ${GREEN}6.${NC} 数据库管理"
    echo " -----------------"
    echo -e " ${GREEN}0.${NC} 退出脚本"
    read -rp "请输入选项 [0-6]: " menu_choice
    echo ""
    case "$menu_choice" in
    1) install_dnmp ;;
    2) uninstall_dnmp ;;
    3) set_dnmp ;;
    4) run_dnmp ;;
    5) stop_dnmp ;;
    6) mg_database ;;
    *) exit 1 ;;
    esac
}

menu

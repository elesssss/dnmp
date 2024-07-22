#!/bin/bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC="\033[0m"

REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")
PACKAGE_UNINSTALL=("apt -y autoremove" "apt -y autoremove" "yum -y autoremove" "yum -y autoremove" "yum -y autoremove")

[[ $EUID -ne 0 ]] && echo -e "${RED}注意：请在root用户下运行脚本${NC}" && acmesslmenu

CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i"
    if [[ -n $SYS ]]; then
        break
    fi
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    if [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]]; then
        SYSTEM="${RELEASE[int]}"
        if [[ -n $SYSTEM ]]; then
            break
        fi
    fi
done

[[ -z $SYSTEM ]] && echo -e "${RED}不支持当前VPS系统, 请使用主流的操作系统${NC}" && acmesslmenu

mainmenu() {
    echo ""
    read -rp "请输入“y”退出, 或按任意键回到主菜单：" mainmenu
    case "$mainmenu" in
    y) exit 1 ;;
    *) menu ;;
    esac
}

runmenu() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" runmenu
    case "$runmenu" in
    y) menu ;;
    *) run_dnmp ;;
    esac
}
stopmenu() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" stopmenu
    case "$stopmenu" in
    y) menu ;;
    *) stop_dnmp ;;
    esac
}

databesemenu() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" databesemenu
    case "$databesemenu" in
    y) menu ;;
    *) mg_database ;;
    esac
}

acmesslmenu() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到当前菜单：" acmesslmenu
    case "$acmesslmenu" in
    y) menu ;;
    *) acmessl ;;
    esac
}

providermenu() {
    echo ""
    read -rp "请输入“y”返回主菜单, 或按任意键回到申请证书菜单：" providermenu
    case "$providermenu" in
    y) menu ;;
    *) acmessl ;;
    esac
}

install_base() {
    echo -e "${GREEN}开始安装依赖...${NC}"
    OS=$(cat /etc/os-release | grep -o -E "Debian|Ubuntu|CentOS" | head -n 1)    
    if [[ "$OS" == "Debian" || "$OS" == "Ubuntu" ]]; then
        commands=("git" "socat" "lsof" "cron" "ip")
        apps=("git" "socat" "lsof" "cron" "iproute2")
        install=()
        for i in ${!commands[@]}; do
            [ ! $(command -v ${commands[i]}) ] && install+=(${apps[i]})
        done
        [ "${#install[@]}" -gt 0 ] && apt update -y && apt install -y ${install[@]}
        systemctl enable --now cron >/dev/null 2>&1
    elif [[ "$OS" == "CentOS" ]]; then
        commands=("git" "socat" "lsof" "crond" "ip")
        apps=("git" "socat" "lsof" "cronie" "iproute")
        install=()
        for i in ${!commands[@]}; do
            [ ! $(command -v ${commands[i]}) ] && install+=(${apps[i]})
        done
        [ "${#install[@]}" -gt 0 ] && yum update -y && yum install -y ${install[@]}
        systemctl enable --now crond >/dev/null 2>&1
    else
        echo -e "${RED}很抱歉，你的系统不受支持！"
        exit 1
    fi

    if ! command -v docker &>/dev/null; then
        curl -fsSL https://get.docker.com | sh >/dev/null 2>&1
        ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin >/dev/null 2>&1
        systemctl enable --now docker >/dev/null 2>&1
    fi
    
    echo -e "${GREEN} 依赖安装完毕！${NC}"
}

install_dnmp() {
    install_base
    echo -e "${GREEN}开始安装 Dnmp...${NC}"
    
    if [ -d "/var/dnmp" ]; then
        echo -e "${GREEN}Dnmp 已安装。${NC}"
    else
        if git clone https://github.com/RyanY610/dnmp.git /var/dnmp; then
            echo -e "${GREEN}Dnmp 安装成功。${NC}"
        else
            echo -e "${RED}Dnmp 安装失败，请检查是否能连通github。${NC}"
            mainmenu
        fi
    fi
    mainmenu
}

install_acme() {
    read -rp "请输入注册邮箱 (例: admin@gmail.com, 或留空自动生成一个gmail邮箱): " acmeEmail
    if [[ -z $acmeEmail ]]; then
        autoEmail=$(date +%s%N | md5sum | cut -c 1-16)
        acmeEmail=$autoEmail@gmail.com
        echo -e "${YELLOW}已取消设置邮箱, 使用自动生成的gmail邮箱: $acmeEmail${NC}"
    fi
    curl https://get.acme.sh | sh -s email=$acmeEmail
    source ~/.bashrc
    bash ~/.acme.sh/acme.sh --upgrade --auto-upgrade
    bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    if [[ -n $(~/.acme.sh/acme.sh -v 2>/dev/null) ]]; then
        echo -e "${GREEN}Acme.sh证书申请脚本安装成功!${NC}"
    else
        echo -e "${RED}抱歉, Acme.sh证书申请脚本安装失败${NC}"
        echo -e "${GREEN}建议如下：${NC}"
        echo -e "${YELLOW}1. 检查VPS的网络环境${NC}"
        echo -e "${YELLOW}2. 脚本可能跟不上时代, 请更换其他脚本${NC}"
    fi
    acmesslmenu
}

set_dnmp() {
    read -p "设置nginx的版本： " nginx_v
    sed -i -e "s/NGINX_V=.*$/NGINX_V=$nginx_v/" /var/dnmp/.env
    read -p "设置mysql的root密码： " mysql_password
    sed -i -e "s/MYSQL_PASSWORD=.*$/MYSQL_PASSWORD=$mysql_password/" /var/dnmp/.env
    read -p "设置mariadb的root密码： " mariadb_password
    sed -i -e "s/MARIADB_PASSWORD=.*$/MARIADB_PASSWORD=$mariadb_password/" /var/dnmp/.env
    read -p "设置redis的密码： " redis_password
    sed -i -e "s/REDIS_PASSWORD=.*$/REDIS_PASSWORD=$redis_password/" /var/dnmp/.env
    echo "设置的信息如下"
    echo -e "${GREEN}nginx${NC}的版本：${GREEN}$nginx_v${NC}"
    echo -e "${GREEN}mysql${NC}的root密码：${GREEN}$mysql_password${NC}"
    echo -e "${GREEN}mariadb${NC}的root密码：${GREEN}$mariadb_password${NC}"
    echo -e "${GREEN}redis${NC}的密码：${GREEN}$redis_password${NC}"
    mainmenu
}

creat_mysql() {
    read -rp "请输入要新建的mysql数据库名：" mysql_name
    [[ -z $mysql_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && databesemenu
    MYSQL_NAME="$mysql_name"

    read -rp "请输入mysql的root密码：" mysql_password
    [[ -z $mysql_password ]] && echo -e "${RED}未输入mysql的root密码，无法执行操作！${NC}" && databesemenu
    MYSQL_PASSWORD="$mysql_password"

    docker exec mysql mysql -uroot -p${MYSQL_PASSWORD} -e "create database ${MYSQL_NAME} default character set utf8mb4 collate utf8mb4_unicode_ci;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${MYSQL_NAME}${NC}创建${GREEN}成功!${NC}"
    else
        echo -e "${RED}输入的密码错误，无法创建数据库！${NC}" && databesemenu
    fi
    databesemenu
}

creat_mariadb() {
    read -rp "请输入要新建的mariadb数据库名：" mariadb_name
    [[ -z $mariadb_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && databesemenu
    MARIADB_NAME="$mariadb_name"

    read -rp "请输入MARIADB的root密码：" mariadb_password
    [[ -z $mariadb_password ]] && echo -e "${RED}未输入mariadb的root密码，无法执行操作！${NC}" && databesemenu
    MARIADB_PASSWORD="$mariadb_password"

    docker exec mariadb mariadb -uroot -p${MARIADB_PASSWORD} -e "create database ${MARIADB_NAME} default character set utf8mb4 collate utf8mb4_unicode_ci;" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${MARIADB_NAME}${NC}创建${GREEN}成功!${NC}"
    else
        echo -e "${RED}输入的密码错误，无法创建数据库！${NC}" && databesemenu
    fi
    databesemenu
}

backup_mysql() {
    read -rp "请输入要备份的mysql数据库名：" mysql_name
    [[ -z $mysql_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && databesemenu
    MYSQL_NAME="$mysql_name"

    read -rp "请输入mysql的root密码：" mysql_password
    [[ -z $mysql_password ]] && echo -e "${RED}未输入mysql的root密码，无法执行操作！${NC}" && databesemenu
    MYSQL_PASSWORD="$mysql_password"

    DATE=$(date +%Y%m%d_%H%M%S)
    LOCK="--skip-lock-tables"

    docker exec mysql bash -c "mysqldump -uroot -p${MYSQL_PASSWORD} ${LOCK} --default-character-set=utf8 --flush-logs -R ${MYSQL_NAME} > /var/lib/mysql/${MYSQL_NAME}_${DATE}.sql" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        cd /var/dnmp/mysql && tar zcpvf /root/${MYSQL_NAME}_${DATE}.sql.tar.gz ${MYSQL_NAME}_${DATE}.sql >/dev/null 2>&1 && rm -f ${MYSQL_NAME}_${DATE}.sql
        echo -e "数据库${GREEN}${MYSQL_NAME}${NC}备份${GREEN}成功${NC}，备份文件${GREEN}${MYSQL_NAME}_${DATE}.sql.tar.gz${NC}在${GREEN}/root/${NC}目录下"
    else
        echo -e "${RED}数据库${MYSQL_NAME}备份失败，请检查root密码or数据库名是否正确！${NC}" && databesemenu
    fi
    databesemenu
}

backup_mariadb() {
    read -rp "请输入要备份的mariadb数据库名：" mariadb_name
    [[ -z $mariadb_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && databesemenu
    MARIADB_NAME="$mariadb_name"

    read -rp "请输入mariadb的root密码：" mariadb_password
    [[ -z $mariadb_password ]] && echo -e "${RED}未输入mariadb的root密码，无法执行操作！${NC}" && databesemenu
    MARIADB_PASSWORD="$mariadb_password"

    DATE=$(date +%Y%m%d_%H%M%S)
    LOCK="--skip-lock-tables"

    docker exec mariadb bash -c "mariadb-dump -uroot -p${MARIADB_PASSWORD} ${LOCK} --default-character-set=utf8 --flush-logs -R ${MARIADB_NAME} > /var/lib/mysql/${MARIADB_NAME}_${DATE}.sql" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        cd /var/dnmp/mariadb && tar zcpvf /root/${MARIADB_NAME}_${DATE}.sql.tar.gz ${MARIADB_NAME}_${DATE}.sql >/dev/null 2>&1 && rm -f ${MARIADB_NAME}_${DATE}.sql
        echo -e "数据库${GREEN}${MARIADB_NAME}${NC}备份${GREEN}成功${NC}，备份文件${GREEN}${MARIADB_NAME}_${DATE}.sql.tar.gz${NC}在${GREEN}/root/${NC}目录下"
    else
        echo -e "${RED}数据库${MARIADB_NAME}备份失败，请检查root密码or数据库名是否正确！${NC}" && databesemenu
    fi
    databesemenu
}

del_mysql() {
    read -rp "请输入要删除的mysql数据库名：" mysql_name
    [[ -z $mysql_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && databesemenu
    MYSQL_NAME="$mysql_name"

    read -rp "请输入mysql的root密码：" mysql_password
    [[ -z $mysql_password ]] && echo -e "${RED}未输入mysql的root密码，无法执行操作！${NC}" && databesemenu
    MYSQL_PASSWORD="$mysql_password"

    docker exec mysql mysql -uroot -p${MYSQL_PASSWORD} -e "drop database ${MYSQL_NAME};" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${MYSQL_NAME}${NC}删除${GREEN}成功!${NC}"
    else
        echo -e "${RED}数据库${MYSQL_NAME}删除失败，请检查root密码or数据库名是否正确！${NC}" && databesemenu
    fi
    databesemenu
}

del_mariadb() {
    read -rp "请输入要删除的mariadb数据库名：" mariadb_name
    [[ -z $mariadb_name ]] && echo -e "${RED}未输入数据库名，无法执行操作！${NC}" && databesemenu
    MARIADB_NAME="$mariadb_name"

    read -rp "请输入MARIADB的root密码：" mariadb_password
    [[ -z $mariadb_password ]] && echo -e "${RED}未输入mariadb的root密码，无法执行操作！${NC}" && databesemenu
    MARIADB_PASSWORD="$mariadb_password"

    docker exec mariadb mariadb -uroot -p${MARIADB_PASSWORD} -e "drop database ${MARIADB_NAME};" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "数据库${GREEN}${MARIADB_NAME}${NC}删除${GREEN}成功!${NC}"
    else
        echo -e "${RED}数据库${MARIADB_NAME}删除失败，请检查root密码or数据库名是否正确！${NC}" && databesemenu
    fi
    databesemenu
}

check_80() {

    if [[ -z $(type -P lsof) ]]; then
        if [[ ! $SYSTEM == "CentOS" ]]; then
            ${PACKAGE_UPDATE[int]}
        fi
        ${PACKAGE_INSTALL[int]} lsof
    fi

    echo -e "${YELLOW}正在检测80端口是否占用...${NC}"
    sleep 1

    if [[ $(lsof -i:"80" | grep -i -c "listen") -eq 0 ]]; then
        echo -e "${GREEN}检测到目前80端口未被占用${NC}"
        sleep 1
    else
        echo -e "${RED}检测到目前80端口被其他程序被占用，以下为占用程序信息${NC}"
        lsof -i:"80"
        read -rp "如需结束占用进程请按Y，按其他键则退出 [Y/N]: " yn
        if [[ $yn =~ "Y"|"y" ]]; then
            lsof -i:"80" | awk '{print $2}' | grep -v "PID" | xargs kill -9
            sleep 1
        else
            acmesslmenu
        fi
    fi
}

acme_standalone() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${RED}未安装acme.sh, 无法执行操作${NC}" && acmesslmenu
    check_80
    WARPv4Status=$(curl -s4m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    WARPv6Status=$(curl -s6m8 https://www.cloudflare.com/cdn-cgi/trace -k | grep warp | cut -d= -f2)
    if [[ $WARPv4Status =~ on|plus ]] || [[ $WARPv6Status =~ on|plus ]]; then
        wg-quick down wgcf >/dev/null 2>&1
        systemctl stop warp-go >/dev/null 2>&1
    fi

    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)

    echo ""
    echo -e "${YELLOW}在使用80端口申请模式时, 请先将您的域名解析至你的VPS的真实IP地址, 否则会导致证书申请失败${NC}"
    echo ""
    if [[ -n $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${NC}"
        echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${NC}"
    elif [[ -n $ipv4 && -z $ipv6 ]]; then
        echo -e "VPS的真实IPv4地址为: ${GREEN} $ipv4 ${NC}"
    elif [[ -z $ipv4 && -n $ipv6 ]]; then
        echo -e "VPS的真实IPv6地址为: ${GREEN} $ipv6 ${NC}"
    fi
    echo ""
    read -rp "请输入解析完成的域名: " domain
    [[ -z $domain ]] && echo -e "${RED}未输入域名，无法执行操作！${NC}" && acmesslmenu
    echo -e "${GREEN}已输入的域名：$domain ${NC}" && sleep 1
    domainIP=$(curl -sm8 ipget.net/?ip="${domain}")

    if [[ $domainIP == $ipv6 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --listen-v6 --insecure
    fi
    if [[ $domainIP == $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue -d ${domain} --standalone --insecure
    fi

    if [[ -n $(echo $domainIP | grep nginx) ]]; then
        if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
            wg-quick up wgcf >/dev/null 2>&1
        fi
        if [[ -e "/opt/warp-go/warp-go" ]]; then
            systemctl start warp-go
        fi
        echo -e "${RED}域名解析失败, 请检查域名是否正确填写或等待解析完成再执行脚本${NC}" && acmesslmenu
    elif [[ -n $(echo $domainIP | grep ":") || -n $(echo $domainIP | grep ".") ]]; then
        if [[ $domainIP != $ipv4 ]] && [[ $domainIP != $ipv6 ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go
            fi
            echo -e "${GREEN}域名 ${domain} 目前解析的IP: ($domainIP) ${NC}"
            echo -e "${RED}当前域名解析的IP与当前VPS使用的真实IP不匹配${NC}"
            echo -e "${GREEN}建议如下：${NC}"
            echo -e "${YELLOW}1. 请确保CloudFlare小云朵为关闭状态(仅限DNS), 其他域名解析或CDN网站设置同理${NC}"
            echo -e "${YELLOW}2. 请检查DNS解析设置的IP是否为VPS的真实IP${NC}"
            echo -e "${YELLOW}3. 脚本可能跟不上时代, 建议更换其他的脚本${NC}"
            acmesslmenu
        fi
    fi

    CERT1PATH=/var/dnmp/nginx/ssl
    mkdir -p $CERT1PATH/${domain}

    bash ~/.acme.sh/acme.sh --install-cert -d ${domain} --key-file "$CERT1PATH"/${domain}/key.pem --fullchain-file "$CERT1PATH"/${domain}/cert.pem
    checktls
}

acme_cfapiNTLD() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${RED}未安装acme.sh，无法执行操作${NC}" && acmesslmenu
    ipv4=$(curl -s4m8 ip.p3terx.com -k | sed -n 1p)
    ipv6=$(curl -s6m8 ip.p3terx.com -k | sed -n 1p)

    domains=()
    read -rp "请输入需要申请的域名数量: " domains_count
    [[ ! $domains_count =~ ^[1-99][0-99]*$ ]] && echo -e "${RED}请输入有效的域名数量！${NC}" && acmesslmenu
    for ((i = 1; i <= domains_count; i++)); do
        read -rp "请输入第 $i 个域名 (例如：domain.com): " domain
        domains+=("$domain")
    done

    read -rp "请输入 Cloudflare Global API Key: " cf_key
    [[ -z $cf_key ]] && echo -e "${RED}未输入 Cloudflare Global API Key，无法执行操作！${NC}" && acmesslmenu
    CF_Key="$cf_key"
    read -rp "请输入 Cloudflare 的登录邮箱: " cf_email
    [[ -z $cf_email ]] && echo -e "${RED}未输入 Cloudflare 的登录邮箱，无法执行操作!${NC}" && acmesslmenu
    CF_Email="$cf_email"

    first_domain="${domains[0]}"
    acme_domains=""
    for domain in "${domains[@]}"; do
        acme_domains+=" -d $domain -d *.$domain"
    done

    if [[ -z $ipv4 ]]; then
        bash ~/.acme.sh/acme.sh --issue --dns dns_cf --listen-v6 --insecure $acme_domains
    else
        bash ~/.acme.sh/acme.sh --issue --dns dns_cf --insecure $acme_domains
    fi

    CERT3PATH=/var/dnmp/nginx/ssl
    mkdir -p $CERT3PATH/$first_domain

    for domain in "${domains[@]}"; do
        bash ~/.acme.sh/acme.sh --install-cert -d "$first_domain" --key-file "$CERT3PATH"/"$first_domain"/key.pem --fullchain-file "$CERT3PATH"/"$first_domain"/cert.pem

    done

    check1tls
}

check1tls() {
    if [[ -f "$CERT3PATH"/"$first_domain"/cert.pem && -f "$CERT3PATH"/"$first_domain"/key.pem ]]; then
        if [[ -s "$CERT3PATH"/"$first_domain"/cert.pem && -s "$CERT3PATH"/"$first_domain"/key.pem ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go
            fi
            echo $domain >/root/ca.log
            sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
            echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >>/etc/crontab
            echo -e "证书申请成功! 脚本申请到的证书 cert.pem 和私钥 key.pem 文件已保存到 ${GREEN}${CERT3PATH}/${first_domain}${NC} 路径下"
            echo -e "证书crt文件路径如下: ${GREEN}${CERT3PATH}/${first_domain}/cert.pem${NC}"
            echo -e "私钥key文件路径如下: ${GREEN}${CERT3PATH}/${first_domain}/key.pem${NC}"
            acmesslmenu
        else
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go
            fi
            echo -e "${RED}很抱歉，证书申请失败${NC}"
            echo -e "${GREEN}建议如下: ${NC}"
            echo -e "${YELLOW}1. 自行检查dns_api信息是否正确${NC}"
            echo -e "${YELLOW}2. 脚本可能跟不上时代, 建议更换其他脚本${NC}"
            acmesslmenu
        fi
    fi
}

checktls() {
    if [[ -f ${CERT1PATH}/"$domain"/cert.pem && -f ${CERT1PATH}/"$domain"/key.pem ]]; then
        if [[ -s ${CERT1PATH}/"$domain"/cert.pem && -s ${CERT1PATH}/"$domain"/key.pem ]]; then
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go
            fi
            echo $domain >/root/ca.log
            sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
            echo "0 0 * * * root bash /root/.acme.sh/acme.sh --cron -f >/dev/null 2>&1" >>/etc/crontab
            echo -e "${GREEN}证书申请成功! 脚本申请到的证书 cert.pem 和私钥 key.pem 文件已保存到 ${GREEN}${CERT1PATH}/${domain}${NC} 路径下"
            echo -e "${GREEN}证书crt文件路径如下: ${GREEN}${CERT1PATH}/${domain}/cert.pem${NC}"
            echo -e "${GREEN}私钥key文件路径如下: ${GREEN}${CERT1PATH}/${domain}/key.pem${NC}"
            acmesslmenu
        else
            if [[ -n $(type -P wg-quick) && -n $(type -P wgcf) ]]; then
                wg-quick up wgcf >/dev/null 2>&1
            fi
            if [[ -e "/opt/warp-go/warp-go" ]]; then
                systemctl start warp-go
            fi
            echo -e "${RED}很抱歉，证书申请失败${NC}"
            echo -e "${GREEN}建议如下: ${NC}"
            echo -e "${YELLOW}1. 自行检测防火墙是否打开, 如使用80端口申请模式时, 请关闭防火墙或放行80端口${NC}"
            echo -e "${YELLOW}2. 同一域名多次申请可能会触发Let's Encrypt官方风控, 请尝试使用脚本菜单的9选项更换证书颁发机构, 再重试申请证书, 或更换域名、或等待7天后再尝试执行脚本${NC}"
            echo -e "${YELLOW}3. 脚本可能跟不上时代, 建议更换其他脚本${NC}"
            acmesslmenu
        fi
    fi
}

view_cert() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${YELLOW}未安装acme.sh, 无法执行操作!${NC}" && acmesslmenu
    bash ~/.acme.sh/acme.sh --list
    acmesslmenu
}

renew_cert() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${YELLOW}未安装acme.sh, 无法执行操作!${NC}" && acmesslmenu
    bash ~/.acme.sh/acme.sh --list
    read -rp "请输入要续期的域名证书 (复制Main_Domain下显示的域名): " domain
    [[ -z $domain ]] && echo -e "${RED}未输入域名, 无法执行操作!${NC}" && acmesslmenu
    if [[ -n $(bash ~/.acme.sh/acme.sh --list | grep $domain) ]]; then
        bash ~/.acme.sh/acme.sh --renew -d ${domain} --force
        checktls
        acmesslmenu
    else
        echo -e "${RED}未找到${domain}的域名证书，请再次检查域名输入正确${NC}"
        acmesslmenu
    fi
}

switch_provider() {
    echo -e "${YELLOW}请选择证书提供商, 默认通过 Letsencrypt.org 来申请证书 ${NC}"
    echo -e "${YELLOW}如果证书申请失败, 例如一天内通过 Letsencrypt.org 申请次数过多, 可选 BuyPass.com 或 ZeroSSL.com 来申请.${NC}"
    echo -e " ${GREEN}1.${NC} Letsencrypt.org"
    echo -e " ${GREEN}2.${NC} BuyPass.com"
    echo -e " ${GREEN}3.${NC} ZeroSSL.com"
    read -rp "请选择证书提供商 [1-3，默认1]: " provider
    case $provider in
    2) bash ~/.acme.sh/acme.sh --set-default-ca --server buypass && echo -e "${GREEN}切换证书提供商为 BuyPass.com 成功！${NC}" ;;
    3) bash ~/.acme.sh/acme.sh --set-default-ca --server zerossl && echo -e "${GREEN}切换证书提供商为 ZeroSSL.com 成功！${NC}" ;;
    *) bash ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt && echo -e "${GREEN}切换证书提供商为 Letsencrypt.org 成功！${NC}" ;;
    esac
    providermenu
}

uninstall_dnmp() {
    echo -e " ${RED}注意！！！卸载前请先备份 Dnmp 目录${NC}"
    read -p "是否需要备份 Dnmp 目录？([Y]/n 默认备份): " backup_confirm
    if [ -z "$backup_confirm" ] || [ "$backup_confirm" == "y" ]; then

        cd /var && tar zcpvf /root/dnmp.tar.gz dnmp
        echo -e "${GREEN}Dnmp 目录已备份到 /root/dnmp.tar.gz${NC}"
    fi

    read -p "确认卸载 Dnmp 吗？(y/[N] 默认不卸载): " confirm
    if [ "$confirm" == "y" ]; then
        docker stop $(docker ps -a -q) && docker rm $(docker ps -a -q) && docker rmi $(docker images -q) && docker network prune -f
        rm -rf /var/dnmp
        echo -e "${GREEN}Dnmp 已彻底卸载!${NC}"
    else
        echo -e "${YELLOW}取消卸载操作.${NC}"
    fi
    mainmenu
}

uninstall_acme() {
    [[ -z $(~/.acme.sh/acme.sh -v 2>/dev/null) ]] && echo -e "${YELLOW}未安装Acme.sh, 卸载程序无法执行!${NC}" && acmesslmenu
    ~/.acme.sh/acme.sh --uninstall
    sed -i '/--cron/d' /etc/crontab >/dev/null 2>&1
    rm -rf ~/.acme.sh
    echo -e "${GREEN}Acme  一键申请证书脚本已彻底卸载!${NC}"
    acmesslmenu
}

run_dnmp() {
    clear
    echo "请选择你要启动的服务"
    echo ""
    echo -e "${GREEN}1.${NC} 启动${GREEN}nginx${NC}"
    echo -e "${GREEN}2.${NC} 启动${GREEN}php7.4${NC}"
    echo -e "${GREEN}3.${NC} 启动${GREEN}php8.1${NC}"
    echo -e "${GREEN}4.${NC} 启动${GREEN}php8.2${NC}"
    echo -e "${GREEN}5.${NC} 启动${GREEN}php8.3${NC}"
    echo -e "${GREEN}6.${NC} 启动${GREEN}mysql${NC}"
    echo -e "${GREEN}7.${NC} 启动${GREEN}mariadb${NC}"
    echo -e "${GREEN}8.${NC} 启动${GREEN}redis${NC}"
    echo "0. 返回主菜单"
    echo ""
    read -p "请输入选项 [0-8 用空格分开]: " -a options

    services=""

    for option in "${options[@]}"; do
        if [[ "$option" != [0-7] ]]; then
            menu
        else
            case $option in
            1) services+="nginx " ;;
            2) services+="php7.4 " ;;
            3) services+="php8.1 " ;;
            4) services+="php8.2 " ;;
            5) services+="php8.3 " ;;
            6) services+="mysql " ;;
            7) services+="mariadb " ;;
            8) services+="redis " ;;
            *) menu ;;
            esac
        fi
    done

    if [[ -n $services ]]; then
        cd /var/dnmp && docker-compose up -d $services && runmenu
    fi
}

stop_dnmp() {
    clear
    echo "请选择您想要停止的服务"
    echo -e "${YELLOW}注意！！！停止mysql、mariadb和redis将清除这3个服务的数据${NC}"
    echo ""
    echo -e "${GREEN}1.${NC} ${RED}停止nginx${NC}"
    echo -e "${GREEN}2.${NC} ${RED}停止php7.4${NC}"
    echo -e "${GREEN}3.${NC} ${RED}停止php8.1${NC}"
    echo -e "${GREEN}4.${NC} ${RED}停止php8.2${NC}"
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
        3) docker stop php8.1 && docker rm php8.1 ;;
        4) docker stop php8.2 && docker rm php8.2 ;;
        5) docker stop mysql && docker rm mysql && rm -rf /var/dnmp/mysql ;;
        6) docker stop mariadb && docker rm mariadb && rm -rf /var/dnmp/mariadb ;;
        7) docker stop redis && docker rm redis && rm -rf /var/dnmp/redis ;;
        *) menu ;;
        esac
    done
    stopmenu
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
    read -rp "请输入选项 [0-6]: " mg_database
    case $mg_database in
    1) creat_mysql ;;
    2) backup_mysql ;;
    3) del_mysql ;;
    4) creat_mariadb ;;
    5) backup_mariadb ;;
    6) del_mariadb ;;
    *) menu ;;
    esac
    databesemenu
}

acmessl() {
    clear
    echo ""
    echo " -------------"
    echo -e " ${GREEN}1.${NC} 安装 Acme.sh 域名证书申请脚本"
    echo -e " ${GREEN}2.${NC} ${RED}卸载 Acme.sh 域名证书申请脚本${NC}"
    echo " -------------"
    echo -e " ${GREEN}3.${NC} 申请单域名证书 ${YELLOW}(80端口申请)${NC}"
    echo -e " ${GREEN}4.${NC} 申请泛域名证书 ${YELLOW}(CF API申请)${NC} ${GREEN}(无需解析)${NC} ${RED}(不支持freenom域名)${NC}"
    echo " -------------"
    echo -e " ${GREEN}5.${NC} 查看已申请的证书"
    echo -e " ${GREEN}6.${NC} 手动续期已申请的证书"
    echo -e " ${GREEN}7.${NC} 切换证书颁发机构"
    echo " -------------"
    echo -e " ${GREEN}0.${NC} 返回主菜单"
    echo ""
    read -rp "请输入选项 [0-7]: " acmessl
    case "$acmessl" in
    1) install_acme ;;
    2) uninstall_acme ;;
    3) acme_standalone ;;
    4) acme_cfapiNTLD ;;
    5) view_cert ;;
    6) renew_cert ;;
    7) switch_provider ;;
    *) menu ;;
    esac
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
    echo -e " ${GREEN}7.${NC} Acme申请证书"
    echo " -----------------"
    echo -e " ${GREEN}0.${NC} 退出脚本"
    read -rp "请输入选项 [0-7]: " meun
    echo ""
    case "$meun" in
    1) install_dnmp ;;
    2) uninstall_dnmp ;;
    3) set_dnmp ;;
    4) run_dnmp ;;
    5) stop_dnmp ;;
    6) mg_database ;;
    7) acmessl ;;
    *) exit 1 ;;
    esac
}

menu

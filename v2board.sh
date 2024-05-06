#!/bin/sh
#
#Date:2022.06.05
#Author:Ali Hassanzadeh
#github:github.com/ipmartnetwork

process()
{
install_date="V2board_install_$(date +%Y-%m-%d_%H:%M:%S).log"
printf "
\033[36m#######################################################################
#          Welcome to use V2board one-click deployment script      #
#       Script adapter environment CentOS7+/RetHot7+, memory 1G+   #
#For more information please visit https://github.com/ipmartnetwork#
#######################################################################\033[0m
"

while :; do echo
    read -p "Please enter the Mysql database root password: " Database_Password 
    [ -n "$Database_Password" ] && break
done

# Start counting script execution time after receiving information
START_TIME=`date +%s`


echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#            Disabling SElinux policy, please wait~                   #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
setenforce 0
#Temporarily turn off SElinux
sed -i "s/SELINUX=enforcing/SELINUX=disabled/" /etc/selinux/config
#Permanently turn off SElinux

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#      Configuring Firewall policy. Please wait.                      #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --reload
firewall-cmd --zone=public --list-ports
#Release TCP ports 80 and 443


echo -e "\033[36m########################################################################################\033[0m"
echo -e "\033[36m#                                                                                               #\033[0m"
echo -e "\033[36m#Downloading the installation package, it will take a long time, please wait~                   #\033[0m"
echo -e "\033[36m#                                                                                               #\033[0m"
echo -e "\033[36m########################################################################################\033[0m"
# Download the installation package
git clone https://gitee.com/gz1903/lnmp_rpm.git /usr/local/src/lnmp_rpm
cd /usr/local/src/lnmp_rpm
# Install nginx，mysql，php，redis
echo -e "\033[36mDownload complete, start installation~\033[0m"
rpm -ivhU /usr/local/src/lnmp_rpm/*.rpm --nodeps --force --nosignature
 
# Start nmp
systemctl start php-fpm.service mysqld redis

# Add to boot
systemctl enable php-fpm.service mysqld nginx redis

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#           Configuring Mysql database. Please wait~                  #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
mysqladmin -u root password "$Database_Password"
echo "---mysqladmin -u root password "$Database_Password""
#Change database password
mysql -uroot -p$Database_Password -e "CREATE DATABASE v2board CHARACTER SET utf8 COLLATE utf8_general_ci;"
echo $?="Creating v2board database"

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#               Configuring PHP.ini, please wait~                     #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
sed -i "s/post_max_size = 8M/post_max_size = 32M/" /etc/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 600/" /etc/php.ini
sed -i "s/max_input_time = 60/max_input_time = 600/" /etc/php.ini
sed -i "s#;date.timezone =#date.timezone = Asia/Shanghai#" /etc/php.ini
# Configure php-sg11
mkdir -p /sg
wget -P /sg/  https://cdn.jsdelivr.net/gh/gz1903/sg11/Linux%2064-bit/ixed.7.3.lin
sed -i '$a\extension=/sg/ixed.7.3.lin' /etc/php.ini
#Modify PHP configuration file
echo $?="PHP.ininConfiguration completed"

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#              Configuring Nginx, please wait~                        #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
cp -i /etc/nginx/conf.d/default.conf{,.bak}
cat > /etc/nginx/conf.d/default.conf <<"eof"
server {
    listen       80;
    root /usr/share/nginx/html/v2board/public;
    index index.html index.htm index.php;

    error_page   500 502 503 504  /50x.html;
    #error_page   404 /404.html;
    #fastcgi_intercept_errors on;

    location / {
        try_files $uri $uri/ /index.php$is_args$query_string;
    }
    location = /50x.html {
        root   /usr/share/nginx/html/v2board/public;
    }
    #location = /404.html {
    #    root   /usr/share/nginx/html/v2board/public;
    #}
    location ~ \.php$ {
        root           html;
        fastcgi_pass   127.0.0.1:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  /usr/share/nginx/html/v2board/public/$fastcgi_script_name;
        include        fastcgi_params;
    }
    location /downloads {
    }
    location ~ .*\.(js|css)?$
    {
        expires      1h;
        error_log off;
        access_log /dev/null;
    }
}
eof

cat > /etc/nginx/nginx.conf <<"eon"

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;
    #fastcgi_intercept_errors on;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
eon

mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/v2board.conf

# Create a php test file
touch /usr/share/nginx/html/phpinfo.php
cat > /usr/share/nginx/html/phpinfo.php <<eos
<?php
	phpinfo();
?>
eos

echo -e "\033[36m#######################################################################\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#           V2board is being deployed. Please wait.                   #\033[0m"
echo -e "\033[36m#                                                                     #\033[0m"
echo -e "\033[36m#######################################################################\033[0m"
rm -rf /usr/share/nginx/html/v2board
cd /usr/share/nginx/html
git clone https://github.com/v2board/v2board.git
cd /usr/share/nginx/html/v2board
echo -e "\033[36mPlease enter y to confirm the installation： \033[0m"
sh /usr/share/nginx/html/v2board/init.sh
git clone https://gitee.com/gz1903/v2board-theme-LuFly.git /usr/share/nginx/html/v2board/public/LuFly
mv /usr/share/nginx/html/v2board/public/LuFly/* /usr/share/nginx/html/v2board/public/
chmod -R 777 /usr/share/nginx/html/v2board
# Add scheduled tasks
echo "* * * * * root /usr/bin/php /usr/share/nginx/html/v2board/artisan schedule:run >/dev/null 2>/dev/null &" >> /etc/crontab
# Install Node.js
curl -sL https://rpm.nodesource.com/setup_10.x | bash -
yum -y install nodejs
npm install -g n
n 17
node -v
# Install pm2
npm install -g pm2
# Add a daemon queue
pm2 start /usr/share/nginx/html/v2board/pm2.yaml --name v2board
# Save the existing list data, and automatically load the saved application list to start after booting
pm2 save
# Set the boot
pm2 startup

#Get the host intranet ip
ip="$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}')"
#Get the host external network ip
ips="$(curl ip.sb)"

systemctl restart php-fpm mysqld redis && nginx
echo $?="Service startup completed"
# Clear cache junk
rm -rf /usr/local/src/v2board_install
rm -rf /usr/local/src/lnmp_rpm
rm -rf /usr/share/nginx/html/v2board/public/LuFly

# V2Board Statistics of installation completion time
END_TIME=`date +%s`
EXECUTING_TIME=`expr $END_TIME - $START_TIME`
echo -e "\033[36mThis installation used the$EXECUTING_TIME S!\033[0m"

echo -e "\033[32m--------------------------- Installation Completed ---------------------------\033[0m"
echo -e "\033[32m##################################################################\033[0m"
echo -e "\033[32m#                            V2board                             #\033[0m"
echo -e "\033[32m##################################################################\033[0m"
echo -e "\033[32m database username   :root\033[0m"
echo -e "\033[32m Database password     :"$Database_Password
echo -e "\033[32m Website Directory       :/usr/share/nginx/html/v2board \033[0m"
echo -e "\033[32m Nginx Configuration File  :/etc/nginx/conf.d/v2board.conf \033[0m"
echo -e "\033[32m PHP configuration directory    :/etc/php.ini \033[0m"
echo -e "\033[32m Intranet access       :http://"$ip
echo -e "\033[32m External network access       :http://"$ips
echo -e "\033[32m Installation log files   :/var/log/"$install_date
echo -e "\033[32m------------------------------------------------------------------\033[0m"
echo -e "\033[32m If there are any problems with the installation, please report the installation log file.\033[0m"
echo -e "\033[32m If you have any problems, please seek help here:https://github.comipmartnetwork\033[0m"
echo -e "\033[32m E-mail:ipmart@ipmart.cloud\033[0m"
echo -e "\033[32m------------------------------------------------------------------\033[0m"

}
LOGFILE=/var/log/"V2board_install_$(date +%Y-%m-%d_%H:%M:%S).log"
touch $LOGFILE
tail -f $LOGFILE &
pid=$!
exec 3>&1
exec 4>&2
exec &>$LOGFILE
process
ret=$?
exec 1>&3 3>&-
exec 2>&4 4>&-

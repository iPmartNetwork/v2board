#!/usr/bin/bash


# Generate the random password
char_pool='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
password_length=18
password=""
for _ in $(seq 1 "$password_length"); do
  password+=${char_pool:RANDOM%${#char_pool}:1}
done
# Generate the random password

server_ip=$(hostname -I | cut -d' ' -f1)

NGINX_CONFIG="server {
	listen 80;

	root /var/www/domain/public;
	index index.html index.htm index.php;
	server_name domain;

	location / {
		proxy_redirect off;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
		try_files \$uri \$uri/ /index.php\$is_args\$query_string;  
	}

	location ~ \.php$ {
		proxy_redirect off;
		proxy_http_version 1.1;
		proxy_set_header Upgrade \$http_upgrade;
		proxy_set_header Connection "upgrade";
		proxy_set_header Host \$http_host;
		include snippets/fastcgi-php.conf;
		fastcgi_pass unix:/run/php/php8.1-fpm.sock;
	}

	location ~ /\. {
		deny all;
	}
}"

NGINX_CONFIG2="user www-data;
worker_processes $(grep processor /proc/cpuinfo | wc -l);
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
	worker_connections 1024;
	multi_accept on;
}

http {

    	log_format  main  '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
                      '\$status \$body_bytes_sent \"\$http_referer\" '
                      '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';

    	access_log  /var/log/nginx/access.log  main;

	server_tokens off;
    	sendfile            on;
    	tcp_nopush          on;
    	tcp_nodelay         on;
    	keepalive_timeout   30;
    	types_hash_max_size 4096;
	client_max_body_size 64m;

  	#Gzip Compression
  	#gzip on;
  	#gzip_buffers 16 8k;
  	gzip_comp_level 5;
  	#gzip_min_length 256;
  	#gzip_proxied any;
  	gzip_vary on;
  	gzip_types
    		text/xml application/xml application/atom+xml application/rss+xml application/xhtml+xml image/svg+xml
    		text/javascript application/javascript application/x-javascript
    		text/x-json application/json application/x-web-app-manifest+json
    		text/css text/plain text/x-component
    		font/opentype application/x-font-ttf application/vnd.ms-fontobject
    		image/x-icon;
  	gzip_disable \"MSIE [1-6]\.(?!.*SV1)\";

    	include             /etc/nginx/mime.types;
    	default_type        application/octet-stream;

	include /etc/nginx/conf.d/*.conf;
	include /etc/nginx/sites-enabled/*;
}"

BLUE='\033[1;44m'
BLUE2='\033[1;34m'
RED='\033[1;41m'
RED2='\033[1;31m'
GREEN='\033[1;42m'
GREEN2='\033[1;32m'
NC='\033[0m' # No Color

# ----------- start command --------------

clear

echo "nameserver 1.1.1.1" > /etc/resolv.conf

echo "nameserver 1.0.0.1" >> /etc/resolv.conf

wget -N --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && bash bbr.sh

echo -e "\n${GREEN}Start installing V2board ${NC}\n"

echo -e "${BLUE}First Update the pakage of server ${NC}\n"

sleep 3

apt-get update -y && apt-get upgrade -y

echo -e "\n${BLUE}Install prerequisites ${NC}\n"

sleep 2

add-apt-repository ppa:ondrej/nginx -y

apt update

apt upgrade -y

echo -e "\n${BLUE}3. Install nginx with cerbot ${NC}\n"

sleep 2

apt install nginx certbot python3-certbot-nginx -y

echo -e "\n${GREEN}Installing nginx was finish ${NC}\n"

echo -e "${RED2}Open the ${server_ip} to show first nginx page ${NC}\n"

read -p "$(echo -e "${BLUE2}Is show first nginx page? (yes|no):${NC}  ")" nginx_status

if [[ "$nginx_status" == *[Yy][Ee][Ss]* ]]; 
then
    
    echo -e "\n${GREEN}Excellent, let's continue the work! ${NC}\n"

    echo -e "${RED}Please set record A, your domain to $server_ip${NC}\n"

    read -p "$(echo -e "${BLUE2}Send a domain without https:${NC} ")" domain

    # Validate domain name
    validate="^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\.)+[a-zA-Z]{2,}$"

    # If user doesn't enter anything
    if [[ -z "$domain" ]]; then
        echo -e "\n${RED}You must enter a domain ${NC}\n"
    fi

    if [[ "$domain" =~ $validate ]]; then
        echo -e "\n${GREEN}Domain is valid and saved! ${NC}\n"

        sleep 2

		hostname $domain

        cp /etc/nginx/sites-available/default /etc/nginx/sites-available/$domain

        ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/

        cp -r /var/www/html/ /var/www/$domain

        rm -fr /etc/nginx/sites-available/default

        rm -fr /etc/nginx/sites-enabled/default

        rm -fr /etc/nginx/sites-available/$domain

        rm -fr /etc/nginx/nginx.conf

        echo "${NGINX_CONFIG//domain/"$domain"}"  >> /etc/nginx/sites-available/$domain

        cpu=$(grep processor /proc/cpuinfo | wc -l)

        echo "$NGINX_CONFIG2" >> /etc/nginx/nginx.conf

        systemctl restart nginx

        echo -e "\n${BLUE}installing ssl for $domain ${NC}\n"

        sleep 2

        certbot --nginx -d $domain --register-unsafely-without-email

        echo -e "\n${BLUE}installing php 8.1 version ${NC}\n"

        sleep 2

        sudo apt install redis -y

        sudo add-apt-repository ppa:ondrej/php -y

        apt update

        apt upgrade -y

        apt install zip -y

        apt install p7zip-full p7zip-rar -y

        apt install php8.1-fpm php8.1-common php8.1-mysql \
        php8.1-xml php8.1-xmlrpc php8.1-curl php8.1-gd \
        php8.1-imagick php8.1-cli php8.1-dev php8.1-imap \
        php8.1-mbstring php8.1-opcache php8.1-redis \
        php8.1-soap php8.1-zip php8.1-pgsql -y

        sudo apt install php8.1-cli unzip

        cd ~

        curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php
        HASH=`curl -sS https://composer.github.io/installer.sig`
        php -r "if (hash_file('SHA384', '/tmp/composer-setup.php') === '$HASH') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"

        sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer

		echo "fastcgi_param  SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;" | tee -a /etc/nginx/fastcgi_params > /dev/null

		echo "max_execution_time = 21600" | tee -a /etc/php/8.1/fpm/php.ini > /dev/null

		echo "upload_max_filesize = 100M" | tee -a /etc/php/8.1/fpm/php.ini > /dev/null

		echo "post_max_size = 100M" | tee -a /etc/php/8.1/fpm/php.ini > /dev/null

		echo "max_file_uploads = 20" | tee -a /etc/php/8.1/fpm/php.ini > /dev/null

		echo "max_input_vars = 200" | tee -a /etc/php/8.1/fpm/php.ini > /dev/null

		echo "memory_limit = -1" | tee -a /etc/php/8.1/fpm/php.ini > /dev/null

		echo "max_execution_time = 21600" | tee -a /etc/php/8.1/cli/php.ini > /dev/null

		echo "upload_max_filesize = 100M" | tee -a /etc/php/8.1/cli/php.ini > /dev/null

		echo "post_max_size = 100M" | tee -a /etc/php/8.1/cli/php.ini > /dev/null

		echo "max_file_uploads = 20" | tee -a /etc/php/8.1/cli/php.ini > /dev/null

		echo "max_input_vars = 200" | tee -a /etc/php/8.1/cli/php.ini > /dev/null

		echo "memory_limit = -1" | tee -a /etc/php/8.1/cli/php.ini > /dev/null

		echo -e "\n${BLUE}installing mariadb 10.4 version ${NC}\n"

        sleep 2

		apt-get install software-properties-common
		apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
		add-apt-repository 'deb [arch=amd64,arm64,ppc64el] http://mirrors.up.pt/pub/mariadb/repo/10.4/ubuntu focal main'

		wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb && sudo dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb

		apt install mariadb-server -y

		sudo mysql_secure_installation

		mysql -u root -e "create database v2board;"

		mysql -u root -e "DROP USER 'v2board'@'localhost';"

		mysql -u root -e "create user v2board@localhost identified by '$password';"

		mysql -u root -e "grant all privileges on v2board.* to v2board@localhost;"

        echo -e "\n${BLUE}installing V2board from github ${NC}\n"

        cd /var/www/$domain/

        rm -fr *

        git init

        git remote add origin https://github.com/v2board/v2board.git

        git pull origin master

        composer install

		echo -e "\n${GREEN}your db info:${NC}\nname: v2board\nuser: v2board\npass:$password\n"

        php artisan v2board:install

        sudo chmod -R 755 /var/www/$domain/

        sudo chown -R www-data:www-data /var/www/$domain/

		echo -e "\n${BLUE}installing PM2 ${NC}\n"

		curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -

		sudo apt install -y nodejs

		sudo npm install -g pm2

		cd /var/www/$domain/

		pm2 start pm2.yaml

		pm2 startup

		systemctl enable pm2-root

		pm2 list

		systemctl enable nginx

		systemctl restart nginx


    else
        echo -e "\n${RED}Not valid $domain name.=${NC}\n"
    fi
    
else
    echo -e "\n${RED}Check firewall and open the nginx ports ${NC}\n"
fi

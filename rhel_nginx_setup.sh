#!/usr/bin/env bash

################################################
# Developed by: Andrey M.
# Purpose: Make RHEL linux system comfortable to use after clean install
#	   By updating system packages, install neccessary packages, vim plugins and aliases
# Date: 05-03-2025
# Version: 1.0.0
################################################
set -o errexit
set -o pipefail
set -o nounset
################################################

script_version=1.0.0
script_name=rhel_nginx_setup.sh
update_run=False
ngnix_installed=False
user_folder_run=False
basic_auth_run=False
cgi_run=False

. /etc/os-release
#############################################################################
# Update_system
#############################################################################
Update_system()
{
	if [[ $update_run == True ]]; then
		return 0
	fi
	
	echo System update

	set +o errexit
	yum check-update; yum update -yv
	set -o errexit
    update_run=True
}


#############################################################################
# Destruct
#############################################################################
Destruct()
{
    # Destruct, delete local variables
    unset script_version
    unset script_name
    unset update_run
    unset ngnix_installed
    unset user_folder_run
    unset basic_auth_run
    unset cgi_run
}


#############################################################################
# Run_all
#############################################################################
Run_all(){
    Install_nginx
    User_folder
    Domain_vhost
    Basic_auth
    Fast_cgi
}


#############################################################################
# Install_nginx
#############################################################################
Install_nginx(){
    # check if nginx and needed modules is installed
    n_modules=(nginx epel-release certbot python3-certbot-nginx httpd-tools fcgiwrap)

    #looping through the elements to print 
    for item in ${n_modules[@]}; do
        Update_system
        if ! rpm -q $item &>/dev/null; then
            echo "Installing $item"
            yum -y install $item
        else
            echo "$item is already installed"
        fi
    done
    
    # Run nginx
    systemctl enable --now nginx
    
    ngnix_installed=True
}


#############################################################################
# Domain_vhost
#############################################################################
Domain_vhost(){
    echo "Create Vrtual Host for domain"
    echo
    read -p "Username of domain manager? " user_domain
    stop_loop='no'
    until [[ "${stop_loop,,}" == 'yes' || "${stop_loop,,}" == 'y' ]]
    do
        read -p  "Enter domain name: " domain
        if [[ -z "$domain" ]]; then # empty -> quite
            stop_loop='y'
        else
            Create_vhost $domain $user_domain
            read -p "Done? [y/n] " stop_loop
        fi
        
    done

    unset stop_loop
}


#############################################################################
# Create_vhost
#############################################################################
Create_vhost(){

    # check if site content folder exists
    if [[ ! -d  "/usr/share/nginx/$1/html" ]]; then
        mkdir -p /usr/share/nginx/$1/html
        echo "<html>Welcome!!!</html>" > /usr/share/nginx/$1/html/index.html
        chown -R $2:nginx /usr/share/nginx/$1/html
        chmod -R 755 /usr/share/nginx
    fi

    # check if config file exist
    if [[ ! -f "/etc/nginx/conf.d/$1.conf" ]]; then
        cat << EOF > "/etc/nginx/conf.d/$1.conf"
server {
    listen       80;
    listen       [::]:80;
    server_name  $1 www.$1;
    root         /usr/share/nginx/$1/html;

    access_log  /var/log/nginx/www_access.log;
    error_log   /var/log/nginx/www_error.log;
    
    location / {
            try_files \$uri \$uri/ =404;
            index  index.html index.htm;
    }
}
EOF
        # CHANGE FOR REAL IP FOR NOT LOCAL SITES !!!!!!!!!!!!!
        echo "127.0.0.1   $1" >> /etc/hosts
        echo "127.0.0.1   wwww.$1" >> /etc/hosts

        echo "Adding ssl."
        echo "skipping for localhost domains"
        #certbot --nginx -d $1 -m admin@$1 --agree-tos
        #certbot renew --dry-run
        

        # restart nginx
        systemctl restart nginx
    fi

    echo "site located at: /usr/share/nginx/$1/html"
}


################################################################################
# User_folder                                                          
################################################################################
User_folder(){

    if [[ $user_folder_run == True ]]; then
		return 0
	fi

    # check if config file exist
    if [[ ! -f "/etc/nginx/conf.d/userdir.conf" ]]; then
        # get domain from where user domain will accasable
        read -p "Enter domain for user directory: " ud_domain
        
        if [[ -z $ud_domain ]]; then # empty -> do nothing
            return 1
        fi

        cat << EOF > "/etc/nginx/conf.d/userdir.conf"
server {
    listen       80;
    listen       [::]:80;
    server_name  $ud_domain www.$ud_domain;

    access_log  /var/log/nginx/www_access.log;
    error_log   /var/log/nginx/www_error.log;
    
    location ~ ^/~(.+?)(/.*)?$ {
        alias /home/\$1/public_html\$2;
        index  index.html index.htm;
    }


}
EOF
        chmod 711 /home/*
        chmod 755 -R /home/*/public_html
        # CHANGE FOR REAL IP FOR NOT LOCAL SITES !!!!!!!!!!!!!
        echo "127.0.0.1   $ud_domain" >> /etc/hosts
        echo "127.0.0.1   wwww.$ud_domain" >> /etc/hosts

        echo "Adding ssl."
        echo "skipping for localhost domains"
        #certbot --nginx -d $1 -m admin@$1 --agree-tos
        #certbot renew --dry-run
        

        # restart nginx
        systemctl restart nginx

        unset ud_domain
    fi

    echo "site located at: /home/<user>/public_html/"

    user_folder_run=True
}


################################################################################
# Basic_auth                                                         
################################################################################
Basic_auth(){

    if [[ $basic_auth_run == True ]]; then
		return 0
	fi

    # check if config file exist
    if [[ ! -f "/etc/nginx/conf.d/basicauth.conf" ]]; then
        
        cat << EOF > "/etc/nginx/conf.d/basicauth.conf"
location /auth-basic/ {
    auth_basic            "Basic Auth";
    auth_basic_user_file  "/etc/nginx/.htpasswd";
}
EOF
        
        # check if site content folder exists
        if [[ ! -d  "/usr/share/nginx/html/basicauth" ]]; then
            mkdir -p /usr/share/nginx/html/basicauth
            echo "<html>basic auth!!!</html>" > /usr/share/nginx/html/basicauth/index.html
            chmod -R 777 /usr/share/nginx/html/basicauth
        fi

        htpasswd -c -b /etc/nginx/.htpasswd test test
        # restart nginx
        systemctl restart nginx
    fi

    echo "site located at: http://localhost/basicauth user/pwd: test/test"

    basic_auth_run=True
}



################################################################################
# Fast_cgi                                                         
################################################################################
Fast_cgi(){

    if [[ $cgi_run == True ]]; then
		return 0
	fi

    # check if config file exist
    if [[ ! -f "/etc/nginx/conf.d/basicauth.conf" ]]; then
        
        cat << EOF > "/etc/nginx/conf.d/cgi.conf"
location /cgi-bin/ {
    gzip off;
    root  /usr/share/nginx;
    fastcgi_pass  unix:/var/run/fcgiwrap.socket;
    include /etc/nginx/fastcgi_params;
    fastcgi_param SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
}
EOF
        
        # check if site content folder exists
        if [[ ! -d  "/usr/share/nginx/cgi-bin" ]]; then
             mkdir /usr/share/nginx/cgi-bin
             chmod 755 /usr/share/nginx/cgi-bin
 
        fi
        
        pgrep -x fcgiwrap > /dev/null || spawn-fcgi -s /run/fcgiwrap.socket -M 777 -- /usr/sbin/fcgiwrap &
        
        cat << EOF > "/usr/share/nginx/cgi-bin/index.cgi"
#!/usr/bin/python3

print("Content-type: text/html\n")
print("<html>\n<body>")
print("<div style=\"width: 100%; font-size: 40px; font-weight: bold; text-align: center;\">")
print("CGI Script Test Page")
print("</div>")
print("</body>\n</html>")
EOF
        chmod 755 /usr/share/nginx/cgi-bin/index.cgi
    fi
    systemctl restart nginx
    echo "site located at: http://localhost/cgi-bin"

    cgi_run=True
}

################################################################################
# Help                                                                         
################################################################################
Help(){
	# Display Help
	echo "
Install and basic Nginx settings on Red Hat linux distibutive.
Must be root/sudo to run this script.
Without any parrameters will make all options.
	
	Syntax: rhel_nginx_setup.sh [-h|a|u|v|n|d|b|c]
	options:
	-h          Print this help
	-a          Make all options
	-u          Allow to run site from user home folder
	-v          Show version
	-n          Install nginx and ngnix extra packages
	-d          Create virtual host for domain
	-b          Test basic authentication
    	-c          CGI test

 	"
 }



############################################################################
# Version
############################################################################
Version(){
    echo "$script_name version: $script_version"
}

############################################################################
# Main
############################################################################
Main(){

   # Check if the script is run with sudo
   if (( "$EUID" > 0 )); then
	echo "Please run this script with  sudo."
	Destruct
	exit 1
   fi

   if [[ "$1" == "" ]]; then
        Run_all
        exit 0
    fi

    # check options -
    while getopts ":hvcanudb" opt; do
        case ${opt} in
            h)
                Help
                Destruct
                exit 0
                ;;
            v)
                Version
                Destruct
                exit 0
                ;;
            a)
                Run_all
                Destruct
                exit 0
                ;;
            n)
                Install_nginx
                ;;
            d)
                Domain_vhost
                ;;
            u)
                User_folder
                ;;
            b)
                Basic_auth
                ;;
            c)
                Fast_cgi
                ;;
            :)
                echo "Option -$OPTARG requires an argument."
                Destruct
                exit 1
                ;;
            ?)
                echo "Invalid option: -${OPTARG}."
                Destruct
                exit 1
                ;;
        esac
    done
	
}

Main "$@"
Destruct
exit 0

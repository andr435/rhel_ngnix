#!/usr/bin/env bash

################################################
# Developed by: Andrey M.
# Purpose: Make RHEL linux system comfortable to use after clean install
#	   By updating system packages, install neccessary packages, vim plugins and aliases
# Date: 13-03-2025
# Version: 1.0.1
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
cgi_file="#!/usr/bin/python3

print('Content-type: text/html\n')
print('<html>\n<body>')
print('<div style=\'width: 100%; font-size: 40px; font-weight: bold; text-align: center;\'>')
print('CGI Script Test Page')
print('</div>')
print('</body>\n</html>')"

host_template="
server {
    listen       80;
    listen       [::]:80;
    server_name  $v_domain www.$v_domain;
    root         /usr/share/nginx/$v_domain/html;

    access_log  /var/log/nginx/www_access.log;
    error_log   /var/log/nginx/www_error.log;
    
    location / {
            try_files \$uri \$uri/ =404;
            index  index.html index.htm;
    }

    $v_add_dat
}
"
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
    
    return 0
}


#############################################################################
# Destruct
#############################################################################
Destruct()
{
    # Destruct, delete variables
    unset script_version
    unset script_name
    unset update_run
    unset ngnix_installed
    unset user_folder_run
    unset basic_auth_run
    unset cgi_run
    unset cgi_file
    unset host_template

    return 0
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
    Destruct
    return 0
}


#############################################################################
# Install_nginx
#############################################################################
Install_nginx(){
    if [[ $ngnix_installed == True ]]; then
		return 0
	fi

    # check if nginx and needed modules is installed
    local n_modules=(nginx epel-release certbot python3-certbot-nginx httpd-tools fcgiwrap)

    #looping through the elements to print 
    for item in "${n_modules[@]}"; do
        Update_system
        if ! rpm -q "$item" &>/dev/null; then
            echo "Installing $item"
            yum -y install "$item"
        else
            echo "$item is already installed"
        fi
    done
    
    # Run nginx
    systemctl enable --now nginx
    
    ngnix_installed=True

    return 0
}


#############################################################################
# Domain_vhost
#############################################################################
Domain_vhost(){
    echo "Create Vrtual Host for domain"
    read -p -r "Username of domain manager? " user_domain
    local stop_loop='no'
    until [[ "${stop_loop,,}" == 'yes' || "${stop_loop,,}" == 'y' ]]
    do
        read -p -r  "Enter domain name: " domain
        if [[ -z "$domain" ]]; then # empty -> quite
            stop_loop='y'
        else
            Create_vhost "$domain" "$user_domain"
            read -p -r "Done? [y/n] " stop_loop
        fi
        
    done
    unset user_domain
    unset domain
}


#############################################################################
# Create_vhost
#############################################################################
Create_vhost(){ # $1=domain  $2=user $3=additional data

    # check if site content folder exists
    if [[ ! -d  "/usr/share/nginx/$1/html" ]]; then
        mkdir -p /usr/share/nginx/"$1"/html
        echo "<html>Welcome!!!</html>" > /usr/share/nginx/"$1"/html/index.html
        chown -R "$2":nginx /usr/share/nginx/"$1"/html
        chmod -R 755 /usr/share/nginx
    fi

    # check if config file exist
    if [[ ! -f "/etc/nginx/conf.d/$1.conf" ]]; then
        local v_domain=$1
        local v_add_dat=$3
        $host_template > "/etc/nginx/conf.d/$1.conf"

        # CHANGE FOR REAL IP FOR NOT LOCAL SITES !!!!!!!!!!!!!
        Update_hosts "127.0.0.1" "$1"
        
        Update_ssl "$1" "admin@$1"

        # restart nginx
        systemctl restart nginx
    fi

    echo "site located at: /usr/share/nginx/$1/html"
}


###############################################################################
# Update_hosts
###############################################################################
Update_hosts(){ # $1 ip $2 domain
    echo "Update host file"

    echo "$1   $2" >> /etc/hosts
    echo "$1   wwww.$2" >> /etc/hosts

    return 0
}


###############################################################################
# Update_ssl
###############################################################################
Update_ssl(){ # $1 domain $2 admin email
    echo "Adding ssl."
    echo "skipping for localhost domains"
    #certbot --nginx -d $1 -m $2 --agree-tos
    #certbot renew --dry-run
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
        read -p -r "Enter domain for user directory: " v_domain
        
        if [[ -z $v_domain ]]; then # empty -> do nothing
            return 1
        fi

        local v_add_dat="location ~ ^/~(.+?)(/.*)?$ {
            alias /home/\$1/public_html\$2;
            index  index.html index.htm;
        }"

        $host_template > "/etc/nginx/conf.d/userdir.conf"

        chmod 711 /home/*
        chgrp -R nginx /home/*/public_html
        chmod 755 -R /home/*/public_html

        # CHANGE FOR REAL IP FOR NOT LOCAL SITES !!!!!!!!!!!!!
        Update_hosts "127.0.0.1" "$v_domain"

        Update_ssl "$v_domain" "admin@$v_domain"
        
        # restart nginx
        systemctl restart nginx

        unset v_domain
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

         # get domain from where user domain will accasable
        read -p -r "Enter domain for user directory: " v_domain
        
        if [[ -z $v_domain ]]; then # empty -> do nothing
            return 1
        fi
        
        local v_add_dat="location /auth-basic/ {
            auth_basic            \"Basic Auth\";
            auth_basic_user_file  \"/etc/nginx/.htpasswd\";
        }"
        
        $host_template > "/etc/nginx/conf.d/basicauth.conf"
       
        # check if site content folder exists
        if [[ ! -d  "/usr/share/nginx/$v_domain/html/basicauth" ]]; then
            mkdir -p /usr/share/nginx/"v_domain"/html/basicauth
            echo "<html>basic auth!!!</html>" > /usr/share/nginx/"$v_domain"/html/basicauth/index.html
            chgrp -R nginx /usr/share/nginx/"$v_domain"
            chmod -R 755 /usr/share/nginx/"$v_domain"
        fi

        htpasswd -c -b /etc/nginx/.htpasswd test test
        # restart nginx
        systemctl restart nginx

        unset v_domain
    fi

    echo "site located at: http://$v_domain/basicauth user/pwd: test/test"

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

         # get domain from where user domain will accasable
        read -p -r "Enter domain for user directory: " v_domain
        
        if [[ -z $v_domain ]]; then # empty -> do nothing
            return 1
        fi

        local v_add_dat="
        location /cgi-bin/ {
            gzip off;
            root  /usr/share/nginx/$v_domain/;
            fastcgi_pass  unix:/var/run/fcgiwrap.socket;
            include /etc/nginx/fastcgi_params;
            fastcgi_param SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
        }"
        $host_template > "/etc/nginx/conf.d/cgi.conf"
        
        # check if site content folder exists
        if [[ ! -d  "/usr/share/nginx/$v_domain/html/cgi-bin" ]]; then
             mkdir -p /usr/share/nginx/"$v_domain"/html/cgi-bin
        fi
        
        pgrep -x fcgiwrap > /dev/null || spawn-fcgi -s /run/fcgiwrap.socket -M 777 -- /usr/sbin/fcgiwrap &
        
        $cgi_file > "/usr/share/nginx/$v_domain/html/cgi-bin/index.cgi"

        chmod 755 /usr/share/nginx/"$v_domain"/html/cgi-bin
        chgrp -R nginx /usr/share/nginx/"$v_domain"
        chmod 755 /usr/share/nginx/"$v_domain"/html/cgi-bin/index.cgi
        systemctl restart nginx    
        unset v_domain
    fi

    
    echo "site located at: http://$v_domain/cgi-bin"

    cgi_run=True
}

################################################################################
# Help                                                                         
################################################################################
Help(){
	# Display Help
	echo "
SYNOPSIS
	$script_name [-h|a|u|v|n|d|b|c]

DESCRIPTION
    Install and basic Nginx settings on Red Hat linux distibutive.
    Must be root/sudo to run this script.
    Without any parrameters will make all options.
	
 OPTIONS
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

   if [[ ! $ID_LIKE =~ rhel ]]; then
        echo "Script run only on Red Hat distributives"
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

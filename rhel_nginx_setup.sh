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
# Init
#############################################################################
Init()
{
	# Script initalization
	# Check if the script is run with sudo
	if (( "$EUID" > 0 )); then
  		echo "Please run this script with  sudo."
		Destruct
  		exit 1
	fi

    version=1.0.0
    update_run=False
    ngnix_installed=False
}


#############################################################################
# Destruct
#############################################################################
Destruct()
{
	# Destruct, delete local variables
	unset version
    unset update_run

}


#############################################################################
# Run_all
#############################################################################
Run_all(){
    Install_nginx
}


#############################################################################
# Install_nginx
#############################################################################
Install_nginx(){
    # check if nginx and needed modules is installed
    n_modules=(nginx)

    #looping through the elements to print 
    for item in ${n_modules[@]}
        do
            # Update_system
            if rpm -q $item | grep 'is not installed'; then
                echo installing $item
             #   yum -y install $item
            else
                echo $item already installed
            fi
        done
    
    # Run nginx
    systemctl enable --now nginx
    
    ngnix_installed=True
}


################################################################################
# Help                                                                         
################################################################################
Help()
{
	# Display Help
	echo "Install and basic Nginx settings"
	echo "Without any parrameters will make all options"
	echo
	echo "Syntax: after-party.sh [-h|a|u|v|i|p|b]"
	echo "options:"
	echo "-h          Print this help"
	echo "-a          Make all options"
	echo "-u          Allow to run site from user home folder"
	echo "-v          Show version"
	echo "-n          Install nginx and ngnix extra packages"
#	echo "-p          Alias to 'prompt'"
	#echo "-b          Alias to 'backup'"
	echo
}



############################################################################
# Version
############################################################################
Version(){
    echo rhel_nginx_setup.sh version: $version
}


############################################################################
# Main
############################################################################
Main()
{
	if [[ "$1" == "" ]]; then
                Run_all
                exit 0
        else

		# check options -
		while getopts ":hvanu" opt; do
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
                :)
                User_folder
                ;;
                ?)
                echo "Invalid option: -${OPTARG}."
                exit 1
                ;;
            esac
        done

	fi
	
}

Init
Main "$@"
Destruct
exit 0
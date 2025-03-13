Basic setup of Nginx, virtual host, website from user home directory, CGI and basic authetnication.
To keep all in one file did not make use of templates for creating virtual hosts files.

## Features
- Automatically installs Ngnix and required dependencies.
- Creates Nginx virtual host configuration files.
- Enables HTTP basic authentication.
- Configures user directories.
- Test configuration of CGI scripting.
- Test configuration of Basic Authentication

###  Usage
Run the script with the required options:  
Without any parrameters will make all options  


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


## Contributing 
Andrey Mussatov

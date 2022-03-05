#!/bin/bash

#########################################################
# VcxSrv GUI support, Chrome, and Xvfb for WSL2 
#########################################################

# Pre-reqs
###########################################################
# Need to have WSL2 installed on your windows system
# Ubuntu 20.04 OS installed in WSL
# JS application (this has only been tested with Angular)
###########################################################


# Steps to get going:
###########################################################
# 1.) Place this script in the root directory of your JS project
# 2.) Make sure it is executable:  chome +x wsl-gcbs.sh
# 3.) Must run script as source. 
#     Example:      source ./wsl-gcbs-setup.sh    or     . ./wsl-gcbs-setup.sh
#  If you run a script without (source or .), the script
# will start as a sub-shell instead of a parent shell. When a sub-shell is activated
# the exports will only exists as long as the sub-shell is processing. Therefore, if you want
# the exports to persists after execution, you need to make sure this script runs in a parent shell.
###########################################################




# Script variables
project_root_dir="$(pwd)"

# check priviledge level ###
check_priviledge_level () {
    if [ `whoami` != root ]; 
    then
        return 1
    fi
}

if [ "$(exec sh -c 'echo "$PPID"')" != "$ZSH" ]; 
then
    echo you\'re in a ZSH subshell
elif [ "$(exec sh -c 'echo "$PPID"')" != "$$" ]; 
then
    echo you\'re in a Bash subshell
fi

# check you are in root of JS project
check_file () { 
    if [ ! -f $1 ];
    then
        return 1 # flase
    fi
}

# takes filename as argument
continue_script () {
    proj_root_check_val=$(check_file $1)
    if [ "$?" -eq 1 ]
    then
        return 1
    fi
}

############################################################
## Install Required Dependencies
############################################################
wsl_gcb_file=$(continue_script ".wsl-gcbs-setup-conf")
if [[ "$?" -eq 1 ]]; 
then

     # null check to proceed or exit
    package_json_file=$(continue_script "package.json")
    if [[ "$?" -eq 1 ]]
    then
        echo "You are not in your project root. Exiting script... "
        exit
    else
        echo "Project root directory found!"
    fi

    # update WSL package list
    sudo apt-get update -y

    # install necessary bash packages for WSL
    dependency_installer () {
        if ! [ -x "$(command -v $1)" ];
        then
            echo "$1 installing... \n"
            sudo apt-get install $1 -y
        else
            echo "$1 installed\n"
        fi
    }
    # required bash packages
    dependency_installer wget
    dependency_installer unzip
    dependency_installer curl 
    dependency_installer libxi6 
    dependency_installer libgconf-2-4
    dependency_installer xvfb
    dependency_installer x11-apps

    # retrieve content from web servers
    get_web_content () {
        if [[ $1 == "error404" ]];
        then
            echo "Bad web address"
            echo "$1 invalid"
            echo "exiting script... "
            exit
        else
            echo "Get request success... \n"
            wget -nv $1 # turn of verbose while allowing error messages
            printf "\n"
        fi
        }

    
    if [[ ! -x "$(command -v google-chrome)" ]] && [[ ! -x "$(command -v chromedriver)" ]];
    then
        # install chrome
        chrome="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
        get_chrome=$(get_web_content $chrome)
        chrome_basename=$(basename "$get_chrome")
        echo "Installing chrome for WSL..."
        apt-get install "./$chrome_basename"
        printf "Verify chrome... $chrome_version\n"
        chrome_version=$(google-chrome --version | awk '{print $3}')

        # install chromedriver
        chromedriver="https://chromedriver.storage.googleapis.com/$chrome_version/chromedriver_linux64.zip"
        get_chromedriver=$(get_web_content $chromedriver)
        chromedriver_basename=$(basename "$get_chromedriver")
    else
        echo "google chrome $chrome_basename and chromedriver $chromedriver_basename installed..."
    fi



    ####################################
    # install VcxSrv on the windows side 
    ####################################

    # Get and clean Windows username from WSL
    username2="$(powershell.exe '$env:UserName')"
    remove_carriage_return () {
        echo $1 | sed $'s/\r$//' 
    }
    username_sed=$(remove_carriage_return $username2)
    echo "printing username..."
    echo $username_sed
    cd "/mnt/c/Users/$username_sed/desktop"
    echo "$(pwd)"

    DIR=/mnt/c/'Program Files'/VcXsrv
    if [ ! -d "$DIR" ]
        then
            # download install script in home directory of windows
            wget --trust-server-names https://sourceforge.net/projects/vcxsrv/files/latest/download

            # Create shell script and run

            { # try

                touch ang_wsl.ps1 
                echo "./vcxsrv-64.1.20.14.0.installer.exe" > ang_wsl.ps1
                echo
                echo "try to run script... "
                echo "$(pwd)"
                powershell.exe -File ./ang_wsl.ps1 

            } || { # catch
                # abort script something went wront 
                echo "Abort.. we failed at Vcxsrv"
                exit
            }


            # Create sym link in home dir of WSL
            # this will allow for easy execution of vcxsrv from WSL
            cd ~
            printf "\nCreating sym link to VcXsrv... "
            ln -s /mnt/c/'Program Files'/VcXsrv/vcxsrv.exe vcxsrv_link &> /dev/null
            printf "\nLink created... "
        else
            printf "VcxSrv already installed!"

    fi
else
    echo "Setup check complete"
fi
####################################
# setup verification conf file
# write config stuff to this file
####################################
cd $project_root_dir
if [ ! -f ".wsl-gcbs-setup-conf" ]
then
    # create setup verification file
    run_script=".wsl-gcbs-setup-conf"
    touch $run_script
    echo "setup complete" > $run_script
else
    printf "\n\n\nWe found .wsl-gcbs-setup-conf!\n"
    
fi


############################################################
## Script Controller
############################################################

# flag context
help="flag -h  :  help command to display help context"
headed="flag --headed   :   sets up GUI environemnt for tests"
uninstall_packages="flag -u  :  uninstall chrome-browser, chromedriver, xvfb and x11-apps"

# flag functions 
Help() 
{
    # Display Help
    echo
    echo 
    echo "Help:"
    echo "Accepts a single param. Can be: "
    echo
    echo "Syntax: wsl-gcbs.sh [-h | --headed ]"
    echo
    echo "$help"
    echo "$headed"
    echo "$uninstall_packages"
    echo
}

Headed()
{
    echo "Setting Up Headed (GUI) Chrome Environment"
    Headed_Environment
    ##### export display 
    ip=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
    export DISPLAY=$ip
}

Headed_Environment() {
    echo "Headed Environment"
    #### start VcxSrv
    cd ~
    ./vcxsrv_link :0 -ac -multiwindow -clipboard -wgl > /dev/null 2>&1 &
    cd /mnt/c && mkdir tmp
    cd $project_root_dir
    ##### export chrome_bin
    # export CHROME_BIN=/mnt/c/'Program Files'/Google/Chrome/Application/chrome.exe
    export CHROME_BIN=/usr/bin/google-chrome
    export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
}

Uninstall()
{
    echo "Uninstall all installed packages this script installed to your WSL distro"
    Uninstall_Clean
    ##### export display 
    ip=:0
    export DISPLAY=$ip
}

Uninstall_Clean() {
    echo "Clean up starting... "

}

wsl_gcb_file=$(continue_script ".wsl-gcbs-setup-conf")
if [ "$?" -eq 0 ] && grep "setup complete" .wsl-gcbs-setup-conf
then

    # this script can only be run in root project directory
    project_root_check=$(continue_script "package.json")
    if [ ! "$?" -eq 0 ]
    then
        echo "package.json not found... exiting... "
        exit
    fi

    # check for sym link to VcxSrv executable
    cd ~
    if [ -L ${vcxsrv_link} ] && [ -e ${vcxsrv_link} ]
    then
        printf "Sym link check. VcXsrv exists!\n"
    else
        ln -s /mnt/c/'Program Files'/VcXsrv/vcxsrv.exe vcxsrv_link &> /dev/null
        cd $project_root_dir
    fi

    # check if param is one of the three
    if [ $# -eq 0 ];
    then
        echo "No argument supplied... Run with -h for help"
    elif [ "$1" = "-h" ];
    then
        echo "we have an -h flag"
        Help
    elif [ "$1" = "--headed" ];
    then
        echo "we have an --headed flag"
        Headed
        elif [ "$1" = "-u" ];
    then
        echo "we have an --headed flag"
        Headed
    else
        printf "\nInvalid flag! Run with -h for help"
    fi

else
    printf "\n\nSetup check. Setup complete."
    printf "\nYou can now run this file with these flags... "
    Help
    
fi



########### reference notes


# # necessary display exports
# export CHROME_BIN=/mnt/c/'Program Files'/Google/Chrome/Application/chrome.exe
# export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0

# Xvfb -ac :99 -screen 0 1280x1024x16 & export DISPLAY=:99

# # start VcxSrv
# cd ~
# ./vcxsrv.exe :0 -ac -multiwindow -clipboard -wgl > /dev/null 2>&1 &

# ng serve
# ng test
# ngx cypress run --browser chrome
# npx cypress run --browser chrome --spec cypress/integration/firsttest.spec.js
# npx cypress open

# to run headlessly - npx cypress run --browser chrome --headless

#!/bin/bash

#############
# Constants #
#############

readonly USER_GROUP_NAME_REGEX="^[a-z_][a-z0-9_-]*[$]?$"
readonly USER_GROUP_ID_REGEX="^[[:digit:]]+$"
readonly TRUE=0
#######################
# Usage Documentation #
#######################

######################################################################
read -r -d '' USAGE << EOF
Usage: nauci_base_init -hs [-n username[,...]] [-G groupname[,...]]
       [-d groupname] [-D groupid] [-u groupname] [-U groupid]
EOF

read -r -d '' HELP_DOCUMENTATION << EOF
$USAGE

Author: trevor.wilson@nauci.org

The nauci_base_init.sh is the entry point for the nauci_base_entry
docker image and is intended to facilitate the initial setup of a
docker container for the purposes of software development. User's may
be added to a list of existing groups with the -G option. The -G
option will not remove existing user's from unlisted groups. Every
user will be added to a developer group which can be set with the -d
option. If the host is setup with a with a developer group that has a
GID matching the container's developer group GID then SGID can be used
to grant both host and container user's privileges to attached volumes
without the need of extending the all encompassing docker
privileges. Each developer will also be added to a USB group. The idea
is similar to the developer group. The USB group will grant access to
attached USB devices without the need of extending the all
encompassing docker privileges. For this to work the GID of the USB
group must match the GID set on the USB bus device nodes of the host.

Some optional parameters have default values. Defaults are enclosed in
brackets as the leading text of the parameter's definition.

       -n: a comma separated list of user names. A new user will be
           created for each username in the list. Each newly created
           user will be given a home directory of the same name in
           /home. If a user already exists with that name, then that
           user will not be created anew, but may be modified in
           adherence with supplied optional parameters.

       -G: a comma separated list of existing groups that the users
           will be added to.

       -d: [developer] the name of the developer group.

       -D: [2000] the GID of the developer group.

       -u: [usb] the name of the usb group.

       -U: [85] the GID of the usb group.

       -s: switch to an interactive shell instead of exiting.

       -h: displays this help document.
       
EOF
######################################################################

####################
# Input Parameters #
####################

defaultDeveloperGroupName="developer" developerGroupName=
defaultDeveloperGid=2000 developerGid=
defaultUsbGroupName="usb" usbGroupName=
defaultUsbGid=85 usbGid=
doSwitchToInteractiveShell=1

declare -a userNames;
declare -a groupNames;
declare -g -a nonExistentGroupNames;

#############
# Functions #
#############
print_usage_with_error_message() {
    printf "\n%s: %s\n%s\n" "$0" "$1" "$USAGE" >&2
    printf "\nTo display the complete help document please run %s -h\n" "$0" >&2
}

print_usage(){
    printf "\n%s\n\n" "$HELP_DOCUMENTATION"
}

validate_id() {
    return $(test -n "$(echo "$1" | grep -E $USER_GROUP_ID_REGEX)")
}

validate_name() {
    return $(test -n "$(echo "$1" | grep -E "$USER_GROUP_NAME_REGEX")")
}

does_group_exist() {    
    return $(test -n "$(getent group $1)")
}

is_group_gid() {
    return $(test "$(getent group $1 | cut -d: -f3)" = "$2")
}

validate_supplementary_group_names() {
    nonExistentGroupNames=();

    for groupName in $@
    do
        if ! does_group_exist "$groupName"
        then
            nonExistentGroupNames+=("$groupName")
            isValid=1
        fi
    done

    return ${#nonExistentGroupNames[@]}
}

##############################
# Optional Parameter Parsing #
##############################

while getopts :hn:g:d:D:u:U:s opt
do
    case $opt in
        n)  readarray -td, userNames <<< "$OPTARG,"; unset userNames[-1];
            for userName in ${userNames[@]}
            do                
                if ! validate_name "$userName"
                then
                    print_usage_with_error_message "$userName is not a valid username."
                    exit 1
                fi
            done
            ;;

        g) readarray -td, groupNames <<< "$OPTARG,"; unset groupNames[-1];
           if ! validate_supplementary_group_names "${groupNames[@]}"
           then
               declare -p nonExistentGroupNames
               print_usage_with_error_message "The following group names were not found in the group database: ${nonExistentGroupNames[*]}."
               exit 1
           fi
           ;;

        d) if validate_name "$OPTARG"
           then
               developerGroupName=$OPTARG
           else
               print_usage_with_error_message "Invalid Group Name: $OPTARG\nGroup names must begin with a lower case letter or underscore, optionally followed by more letters, underscores, and numbers"
               exit 1
           fi
           ;;
        
        D) if validate_id "$OPTARG"
           then
               developerGid="$OPTARG"
           else
               print_usage
               exit 1
           fi
           ;;

        u) if validate_name "$OPTARG"
            then
                usbGroupName="$OPTARG"
            else
                print_usage_with_error_message "Invalid Group Name: $OPTARG\nGroup names must begin with a lower case letter or underscore, optionally followed by more letters, underscores, and numbers"
                exit 1
            fi
            ;;
        
        U) if validate_id "$OPTARG"
           then
               usbGid=$OPTARG
           else
               print_usage
               exit 1
           fi
           ;;

        h) print_usage
           ;;

        s) doSwitchToInteractiveShell=$TRUE
           ;;
        
        '?') print_usage_with_error_message "invalid option -$OPTARG"
             exit 1
             ;;
    esac
done
shift $((OPTIND - 1)) #this leaves any remaining arguments, but removes the options we have processed

##################
# Apply defaults #
##################
developerGroupName=${developerGroupName:-$defaultDeveloperGroupName}
developerGid=${developerGid:-$defaultDeveloperGid}
usbGroupName=${usbGroupName:-$defaultUsbGroupName}
usbGid=${usbGid:-$defaultUsbGid}

#################################
# Process all of the parameters #
#################################

################################################
# Create developer group if it does not exist. #
################################################
if ! does_group_exist "$developerGroupName"
then
    if does_group_exist "$developerGid"
    then
        print_usage_with_error_message "The GID, $developerGid, chosen for the new developer group named, $developerGroupName, is already in use."
        exit 1
    fi

    groupadd -g "$developerGid" "$developerGroupName"
    groupNames+=("$developerGroupName")
    
elif ! $(is_group_gid "$developerGroupName" "$developerGid")
then
    print_usage_with_error_message "The GID of the existing developer group named $developerGroupName does not match the provided GID $developerGid"
    exit 1
fi

#############################################
# Create the usb group if it does not exist #
#############################################
if ! does_group_exist "$usbGroupName"
then
    if does_group_exist "$usbGid"
    then
        print_usage_with_error_message "The GID, $usbGid, chosen for the new usb group named, $usbGroupName, is already in use."
        exit 1
    fi

    groupadd -g "$usbGid" "$usbGroupName"
    groupNames+=("$usbGroupName")
elif ! $(is_group_gid "$usbGroupName" "$usbGid")
then
    print_usage_with_error_message "The GID of the existing usb group named $usbGroupName does not match the provided GID $usbGid"
    exit 1
fi

#######################################################################################################
# Do not bind forwarding server to the loopback address, but instead bind it to the wild card address #
#######################################################################################################
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bk 
sed 's/#[[:space:]]*X11UseLocalhost yes/X11UseLocalhost no/' /etc/ssh/sshd_config.bk > /etc/ssh/sshd_config

##############################
# Create or update each user #
##############################
for userName in ${userNames[@]}
do                

    # if user does not already exist then create the user, otherwise modify the user based on parameters
    if [ -n "$(getent passwd $userName)" ]
    then
        #printf "\nthe user %s exists\nAdding user to the groups [%s]" "$userName" "${groupNames[*]}"
        ( IFS=,; usermod "$userName" -aG "${groupNames[*]}" )
    else
        #printf "\nthe user %s does not exist\nAdding the groups [%s]" "$userName" "${groupNames[*]}"
        #( IFS=,; useradd "$userName" -mG "${groupNames[*]}" -f 0 -e 2018-01-01)
        ( IFS=,; useradd "$userName" -mG "${groupNames[*]}" )
    fi

    # create the dev directory with setgid and develoepr group ownership
    userHome="$(getent passwd ${userName} | cut -d: -f6)"
    mkdir -m 2775 ${userHome}/dev
    chown ${userName}:${developerGroupName} ${userHome}/dev

    # ssh
    mkdir ${userHome}/.ssh/
    sed 's/#[[:space:]]*ForwardX11 no/ForwardX11 yes/' /etc/ssh/ssh_config | sed 's/#[[:space:]]*ForwardX11Trusted yes/ForwardX11Trusted yes/' > $userHome/.ssh/config
    chown -R ${userName}:${userName} ${userHome}/.ssh/
    
done

#############################################
# Optionally switch to an interactive shell #
#############################################
if [ $doSwitchToInteractiveShell == $TRUE ]
then
    #printf "switching to interactive shell"
    exec bash -l
fi

exit 0

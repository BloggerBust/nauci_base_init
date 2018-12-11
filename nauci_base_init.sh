#!/bin/env bash

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
       [-d groupname] [-D groupid] [-u groupname] [-U groupid] [-v
       volume]
EOF

read -r -d '' HELP_DOCUMENTATION << EOF
$USAGE

Author: trevor.wilson@nauci.org
Depends on: POSIX ACL and extended attributes. It may work on other
ACL types depending on how ACL interoperability is handled, but I have
not tested that behavior.

The nauci_base_init.sh is the entry point for the nauci_base_entry
docker image and is intended to facilitate the initial setup of a
docker container for the purposes of software development. Users may
be added to a list of existing groups with the -G option. The -G
option will not remove existing users from unlisted groups. Every user
will be added to a developer group which can be set with the -d
option. If the host is setup with a developer group that has a GID
matching the container's developer group GID then the setgid mode bit
can be used to grant both host and container user privileges to
attached volumes without the need of extending the all encompassing
docker privileges. Each developer will also be added to a USB
group. The idea is similar to the developer group. The USB group will
grant access to attached USB devices without the need of extending
docker privileges. For this to work the GID of the USB group must
match the GID set on the USB bus device nodes of the host.

Some optional parameters have default values. Defaults are enclosed in
brackets as the leading text of the parameters definition.

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
       
       -v: [/shared] a directory passed to docker-run as a volume with
        posixacl support enabled. For each user passed to the -n
        option a directory with the same name as that user will be
        created as a child of /shared. Default ACL rules will be set
        giving the developer group rwx permissions on the named
        directories. A soft link from the user's dev directory will be
        created to their named directory under /shared.

       -s: switch to an interactive shell instead of exiting.

       -h: displays this help document.
EOF
######################################################################

####################
# Input Parameters #
####################

defaultDeveloperVolumeName="/shared" developerVolumeName=
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

while getopts :hn:u:U:g:d:D:v:s opt
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

        v) if [ -d "$OPTARG" ]
           then
               developerVolumeName=$OPTARG
           else
               print_usage_with_error_message "Invalid Developer Volume: $OPTARG\nThe developer volume does not exist."
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
developerVolumeName=${developerVolumeName:-$defaultDeveloperVolumeName}
developerGroupName=${developerGroupName:-$defaultDeveloperGroupName}
developerGid=${developerGid:-$defaultDeveloperGid}
usbGroupName=${usbGroupName:-$defaultUsbGroupName}
usbGid=${usbGid:-$defaultUsbGid}

#################################
# Process all of the parameters #
#################################

######################################################################
# If the developer volume is the default value then validate that it #
# exists                                                             #
######################################################################
if [ "$defaultDeveloperVolumeName" = "$developerVolumeName" ] && ! [ -d "$developerVolumeName" ]
then
    print_usage_with_error_message "Invalid Developer Volume: $developerVolumeName\nThe developer volume does not exist. Since you have not specified a developer volume with the -v option the default developer option was used. It is required that you run the image with a volume attached to the developer volume path."
    exit 1
fi

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
sed 's/#[[:space:]]*X11UseLocalhost yes/X11UseLocalhost no/' /etc/ssh/sshd_config > /etc/ssh/sshd_config.bk && mv /etc/ssh/sshd_config.bk /etc/ssh/sshd_config

##############################
# Create or update each user #
##############################
for userName in ${userNames[@]}
do

    # if user does not already exist then create the user, otherwise modify the user based on parameters
    if [ -n "$(getent passwd $userName)" ]
    then
        ( IFS=,; usermod ${userName} -s /bin/bash -aG "${groupNames[*]}" )
    else
        ( IFS=,; useradd ${userName} -s /bin/bash -mG "${groupNames[*]}" )
    fi

    # create the dev directory with setgid and develoepr group ownership    
    realUserDevDirectory="${developerVolumeName}/${userName}/dev"
    if ! [ -d "${realUserDevDirectory}" ] || ! [ -g "${realUserDevDirectory}" ]
    then
        mkdir -p ${realUserDevDirectory}
        chown :${developerGroupName} ${realUserDevDirectory}
        chmod 2770 ${realUserDevDirectory}
    fi

    # if the default effective ACL permissions have not been set for
    # the developer group, then let's set them now as a convenience
    # since it will be needed. The ACL can always be altered later
    # from a running container.
    if [ -z "$(getfacl -cdep ${realUserDevDirectory} | grep -i ${developerGroupName}:rw.*effective)" ]
    then
        # this will fail if your host / volume is not configured correctly for ACLs
        # As an example zfs *xattr property* must be set to *sa* and the *acltype* must be set to *posixacl* on the host volume
        setfacl -Rdm g:${developerGroupName}:rwx ${realUserDevDirectory}
    fi

    # link the dev directory to the user's home directory
    userHome="$(getent passwd ${userName} | cut -d: -f6)"
    if ! [ -h "${userHome}/dev" ]
    then
        ln -sn ${realUserDevDirectory} ${userHome}/dev
        chown -h ${userName}:${developerGroupName} ${userHome}/dev
    fi
    
    # ssh
    mkdir -p ${userHome}/.ssh/
    sed 's/#[[:space:]]*ForwardX11 no/ForwardX11 yes/' /etc/ssh/ssh_config | sed 's/#[[:space:]]*ForwardX11Trusted yes/ForwardX11Trusted yes/' > $userHome/.ssh/config
    chown -R ${userName}:${userName} ${userHome}/.ssh/

done

####################
# Start ssh daemon #
####################

service ssh start

#############################################
# Optionally switch to an interactive shell #
#############################################
if [ ${doSwitchToInteractiveShell} == ${TRUE} ]
then
    exec bash -l
fi

exit 0

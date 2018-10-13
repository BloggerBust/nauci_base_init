# Nauci Base Entry Image #

I developed [the nauci base entry image](https://hub.docker.com/r/nauci/nauci_base_entry/) for my own project, but I am going to license it as free software so that others may benefit. I have not done that yet because I need to read through the details of the various free software licenses to educate myself on their subtleties in order to choose one that makes sense for my longer term plans. I will be doing this soon, but before I do I will complete [my series on using the nauci base image to separate project dependencies from implementation](https://bloggerbust.ca/series/using-docker-to-separate-dependencies-from-implementation).

# The nauci base image entry point init script usage documentation #

> Usage: nauci_base_init -hs [-n username[,...]] [-G groupname[,...]]
>     [-d groupname] [-D groupid] [-u groupname] [-U groupid]
>
>     Author: trevor.wilson@nauci.org
>
>     The nauci_base_init.sh is the entry point for the nauci_base_entry
>     docker image and is intended to facilitate the initial setup of a
>     docker container for the purposes of software development. Users may
>     be added to a list of existing groups with the -G option. The -G
>     option will not remove existing users from unlisted groups. Every user
>     will be added to a developer group which can be set with the -d
>     option. If the host is setup with a developer group that has a GID
>     matching the container's developer group GID then the setgid mode bit
>     can be used to grant both host and container user privileges to
>     attached volumes without the need of extending the all encompassing
>     docker privileges. Each developer will also be added to a USB
>     group. The idea is similar to the developer group. The USB group will
>     grant access to attached USB devices without the need of extending
>     docker privileges. For this to work the GID of the USB group must
>     match the GID set on the USB bus device nodes of the host.
>
>     Some optional parameters have default values. Defaults are enclosed in
>     brackets as the leading text of the parameters definition.
>
>        -n: a comma separated list of user names. A new user will be
>            created for each username in the list. Each newly created
>            user will be given a home directory of the same name in
>            /home. If a user already exists with that name, then that
>            user will not be created anew, but may be modified in
>            adherence with supplied optional parameters.
>
>        -G: a comma separated list of existing groups that the users
>            will be added to.
>
>        -d: [developer] the name of the developer group.
>
>        -D: [2000] the GID of the developer group.
>
>        -u: [usb] the name of the usb group.
>
>        -U: [85] the GID of the usb group.
>
>        -s: switch to an interactive shell instead of exiting.
>
>        -h: displays this help document.

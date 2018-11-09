
# Nauci Base Entry Image #
I developed [the nauci base entry image](https://hub.docker.com/r/nauci/nauci_base_entry/) for my own project as a means of encapsulating project dependencies into reusable images. I refer to these types of images as dependency images. When I sat down to solve this problem it was actually the first time I had ever used Docker. I knew that I wanted to use Docker to encapsulate project dependencies and provide a way to attach those dependencies to an arbitrary project as needed. After playing with docker for a while I learned about the differences between containers and images and came to the realization that I wanted the container itself to be reusable. I viewed a dependency image as a static starting point that should contain all of the dependencies for a project archetype. I viewed a dependency container as a running instance of those dependencies that can be updated and evolve with the project. It felt natural that development and debugging should take place outside of the container in the same environment as the implementation.

# What does it do? #
Docker containers are isolated from the host to a degree via Linux name spaces. This script allows a host user and a container user to read and write to the same files and directories located on a shared volume that is attached to the container without altering default user name space.

# How does it work? #
The script expects a volume to be attached to the container. The volume must support POSIX ACL with extended attributes enabled. By attaching a volume to a container, a file system is shared between the container and the host. The script requires a list of one or more usernames. Each user is added to a *developer* group. A directory is created per user on the shared file system with the same name as the user. Inside of each user directory, a development directory is created named *dev*. The script sets the group ownership of each user's dev directory to the developer group and then applies a setgid mode bit ensuring that the effective group ownership will be inherited by child processes. Default ACL rules are attached to the dev directory giving read, write and execute permissions to the developer group. Since both the setgid mode bit and the default ACL rules are attached to the directory, they will be enforced by both the host and container. Each of the shared user dev directories is then soft linked inside the corresponding user's home directory. The final touch is to enable X-Forwarding for each user and start the ssh daemon.

# How can it be used? #
The host user can send commands to the guest user via ssh to carry out dependency specific operations. These operations may create, update or delete project related files shared between the host and guest. This allows a developer to code, compile, debug and test an application without having any project dependencies installed on the host system and without context switching from the host to the container environment. For a complete example of how this is achieved please read [Encapsulate Angular WebExtension Dependencies In a Docker Image](https://bloggerbust.ca/post/encapsulate-angular-webextension-dependencies-in-a-docker-image/).

# Prerequisites #
The attached volume must have a file system with POSIX ACL support and extended attributes enabled. It might be the case that other ACL models will also work thanks to ACL interoperability. However, [ACL interoperability is not standardized](http://wiki.linux-nfs.org/wiki/index.php/ACLs#The%5FACL%5FInteroperability%5FProblem) and I have not tested its behaviour.

# License #
I have released this software under the terms of the Apache License, Version 2.0.

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

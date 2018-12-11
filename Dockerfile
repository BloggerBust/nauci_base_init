FROM debian
MAINTAINER dustfinger@nauci.org

RUN apt-get update -qqy; \
    apt-get upgrade -qqy; \
    apt-get -qqy install \
            ca-certificates \
            acl \
            sudo \
            ssh; \    
    apt-get clean;

EXPOSE 22

# see https://github.com/BloggerBust/nauci_base_init for usage
COPY ./nauci_base_init.sh /usr/local/bin
ENTRYPOINT ["nauci_base_init.sh", "-s"]
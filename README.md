OpenVPN server Docker image
===========================

[![](https://github.com/monstrenyatko/docker-openvpn-server/workflows/ci/badge.svg?branch=master)](https://github.com/monstrenyatko/docker-openvpn-server/actions?query=workflow%3Aci)

About
=====

[OpenVPN](https://openvpn.net/) server in the `Docker` container.

Upstream Links
--------------
* Docker Registry @[monstrenyatko/openvpn-server](https://hub.docker.com/r/monstrenyatko/openvpn-server/)
* GitHub @[monstrenyatko/docker-openvpn-server](https://github.com/monstrenyatko/docker-openvpn-server)
* Fork of GitHub @[kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn)


Quick Start
===========

Configure and start two instances of the `OpenVPN` server to listen on `TCP` and `UDP` simultaneously.
Server and client certificates are shared between both instances via `Docker` volume.

Using docker-compose
--------------------
* Configure environment:

  - `DOCKER_REGISTRY`: [**OPTIONAL**] registry prefix to pull image from a custom `Docker` registry:

    ```sh
      export DOCKER_REGISTRY="my_registry_hostname:5000/"
    ```
* Pull prebuilt `Docker` image:

  ```sh
    docker-compose pull
  ```
* Initialize the `UDP` configuration files:

    ```sh
      docker-compose -f docker-compose.init-pki.yml run --rm server-udp \
          ovpn_genconfig -u udp://VPN.SERVER.DNS.NAME -n DNS.SERVER.IP -N \
          -e 'push "dhcp-option DOMAIN DOMAIN.NAME"'
    ```
* Initialize the `PKI`:

    ```sh
      docker-compose -f docker-compose.init-pki.yml run --rm server-udp ovpn_initpki
    ```
* Clean the `PKI` storage:

    ```sh
      docker-compose -f docker-compose.init-pki.yml run --rm server-udp \
          sh -c "find /mnt/pki -mindepth 1 -delete"
    ```
* Move `PKI` to dedicated storage:

    ```sh
      docker-compose -f docker-compose.init-pki.yml run --rm server-udp \
          bash -c "shopt -s dotglob && mv -vf /etc/openvpn/pki/* /mnt/pki/ && rmdir /etc/openvpn/pki"
    ```
* Generate a client certificate without a passphrase:

    ```sh
      docker-compose run --rm server-udp \
          easyrsa build-client-full CLIENT.NAME nopass
    ```
* Retrieve the client configuration with embedded certificates:

    ```sh
      docker-compose run --rm server-udp \
          ovpn_getclient CLIENT.NAME > CLIENT.NAME.VPN.SERVER.DNS.NAME.ovpn
    ```
* Start `UDP` server process:

    ```sh
        docker-compose up -d server-udp
    ```
* Initialize the `TCP` configuration files:

    ```sh
      docker-compose run --rm server-tcp \
          ovpn_genconfig -u tcp://VPN.SERVER.DNS.NAME -n DNS.SERVER.IP -N \
          -e 'push "dhcp-option DOMAIN DOMAIN.NAME"'
    ```
* Start `TCP` server process:

    ```sh
      docker-compose up -d server-tcp
    ```
* Start both servers:

    ```sh
      docker-compose up -d
    ```

Using docker
------------
* Create the `PKI` storage:

    ```sh
      OVPN_DATA_PKI="openvpn-server-data-pki"
      docker volume create --name $OVPN_DATA_PKI
    ```
* Create the `UDP` configuration storage:

    ```sh
      OVPN_DATA_UDP="openvpn-server-data-udp"
      docker volume create --name $OVPN_DATA_UDP
    ```
* Select `docker` image:

    ```sh
      OVPN_IMG="monstrenyatko/openvpn-server"
    ```
* Initialize the `UDP` configuration files:

    ```sh
      docker run -v $OVPN_DATA_UDP:/etc/openvpn --rm $OVPN_IMG \
          ovpn_genconfig -u udp://VPN.SERVER.DNS.NAME -n DNS.SERVER.IP -N \
          -e 'push "dhcp-option DOMAIN DOMAIN.NAME"'
    ```
* Initialize the `PKI`:

    ```sh
      docker run -v $OVPN_DATA_UDP:/etc/openvpn --rm -it $OVPN_IMG ovpn_initpki
    ```
* Clean the `PKI` storage:

    ```sh
      docker run -v $OVPN_DATA_PKI:/mnt --rm $OVPN_IMG \
        sh -c "find /mnt -mindepth 1 -delete"
    ```
* Move `PKI` to dedicated storage:

    ```sh
      docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/mnt \
          --rm $OVPN_IMG \
          bash -c "shopt -s dotglob && mv -vf /etc/openvpn/pki/* /mnt/ && rmdir /etc/openvpn/pki"
    ```
* Generate a client certificate without a passphrase:

    ```sh
      docker run -v $OVPN_DATA_PKI:/etc/openvpn/pki --rm -it $OVPN_IMG \
          easyrsa build-client-full CLIENT.NAME nopass
    ```
* Retrieve the client configuration with embedded certificates:

    ```sh
      docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
          --rm $OVPN_IMG \
          ovpn_getclient CLIENT.NAME > CLIENT.NAME.VPN.SERVER.DNS.NAME.ovpn
    ```
* Start `UDP` server process:

    ```sh
      docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
          --name openvpn-server-udp --restart unless-stopped -d -p 1194:1194/udp \
          --cap-add=NET_ADMIN $OVPN_IMG
    ```
* Create the `TCP` configuration storage:

    ```sh
      OVPN_DATA_TCP="openvpn-server-data-tcp"
      docker volume create --name $OVPN_DATA_TCP
    ```
* Initialize the `TCP` configuration files:

    ```sh
      docker run -v $OVPN_DATA_TCP:/etc/openvpn --rm $OVPN_IMG \
          ovpn_genconfig -u tcp://VPN.SERVER.DNS.NAME -n DNS.SERVER.IP -N \
          -e 'push "dhcp-option DOMAIN DOMAIN.NAME"'
    ```
* Start `TCP` server process:

    ```sh
      docker run -v $OVPN_DATA_TCP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
          --name openvpn-server-tcp --restart unless-stopped -d -p 1194:1194/tcp \
          --cap-add=NET_ADMIN $OVPN_IMG
    ```


Backup
======

Certificates (PKI)
------------------

Backup archive `openvpn-pki.tar` will be created in current directory.

* Create:

    ```sh
      docker run -v $OVPN_DATA_PKI:/mnt --rm -v $(pwd):/backup $OVPN_IMG \
          tar cvf /backup/openvpn-pki.tar -C /mnt .
    ```
    or for `docker-compose`:
    ```sh
      docker-compose run --rm -v $(pwd):/backup server-udp \
          tar cvf /backup/openvpn-pki.tar -C /etc/openvpn/pki .
    ```
* Cleanup and Restore:

    ```sh
      docker run -v $OVPN_DATA_PKI:/mnt --rm $OVPN_IMG \
          sh -c "find /mnt -mindepth 1 -delete"
      docker run -v $OVPN_DATA_PKI:/mnt --rm -v $(pwd):/backup $OVPN_IMG \
          tar xvf /backup/openvpn-pki.tar -C /mnt
    ```
    or for `docker-compose`:
    ```sh
      docker-compose run --rm server-udp \
          sh -c "find /etc/openvpn/pki -mindepth 1 -delete"
      docker-compose run --rm -v $(pwd):/backup server-udp \
          tar xvf /backup/openvpn-pki.tar -C /etc/openvpn/pki
    ```


Build own image
===============

* `default` target platform:

  ```sh
    cd <path to sources>
    DOCKER_BUILDKIT=1 docker build --tag <tag name> .
  ```
* `arm/v6` target platform:

  ```sh
    cd <path to sources>
    DOCKER_BUILDKIT=1 docker build --platform=linux/arm/v6 --tag <tag name> .
  ```


How Does It Work?
=================

See [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn/blob/master/README.md#how-does-it-work)


VPN Details
===========

See [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn#openvpn-details)


Security Discussion
===================

See [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn/blob/master/README.md#security-discussion)


Benefits
========

See [kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn/blob/master/README.md#benefits-of-running-inside-a-docker-container)

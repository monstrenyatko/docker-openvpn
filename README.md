# OpenVPN server for Docker on Raspberry Pi

OpenVPN server in a Docker container complete with an EasyRSA PKI CA.

#### Upstream Links

* Docker Registry @[monstrenyatko/rpi-openvpn-server](https://hub.docker.com/r/monstrenyatko/rpi-openvpn-server/)
* GitHub @[monstrenyatko/rpi-openvpn-server](https://github.com/monstrenyatko/rpi-openvpn-server)
* Fork of GitHub @[kylemanna/docker-openvpn](https://github.com/kylemanna/docker-openvpn)

## Quick Start

Configure and start two instances of the OpenVPN server to listen on `TCP` and `UDP` simultaneously.
Server and client certificates are shared between both instances via Docker volume.

* Create the `PKI` storage:

		OVPN_DATA_PKI="openvpn-server-data-pki"
		docker volume create --name $OVPN_DATA_PKI

* Create the `UDP` configuration storage:

		OVPN_DATA_UDP="openvpn-server-data-udp"
		docker volume create --name $OVPN_DATA_UDP

* Initialize the `UDP` configuration files and certificates:

		docker run -v $OVPN_DATA_UDP:/etc/openvpn --rm monstrenyatko/rpi-openvpn-server \
			ovpn_genconfig -u udp://VPN.SERVER.DNS.NAME -n DNS.SERVER.IP -N \
			-e "push dhcp-option DOMAIN DOMAIN.NAME"
		docker run -v $OVPN_DATA_UDP:/etc/openvpn --rm -it monstrenyatko/rpi-openvpn-server ovpn_initpki

* Move certificates to dedicated `PKI` storage:

		docker run -v $OVPN_DATA_PKI:/mnt --rm -v $(pwd):/backup hypriot/armhf-busybox \
			sh -c "find /mnt -mindepth 1 -delete"

		docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/mnt \
			--rm monstrenyatko/rpi-openvpn-server \
			bash -c "shopt -s dotglob && mv -vf /etc/openvpn/pki/* /mnt/ && rmdir /etc/openvpn/pki"

* Generate a client certificate without a passphrase:

		docker run -v $OVPN_DATA_PKI:/etc/openvpn/pki --rm -it monstrenyatko/rpi-openvpn-server \
			easyrsa build-client-full CLIENT.NAME nopass

* Retrieve the client configuration with embedded certificates:

		docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
			--rm monstrenyatko/rpi-openvpn-server \
			ovpn_getclient CLIENT.NAME > CLIENT.NAME.VPN.SERVER.DNS.NAME.ovpn

* Start `UDP` server process:

		docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
			-v /etc/localtime:/etc/localtime \
			--name openvpn-server-udp --restart unless-stopped -d -p 1194:1194/udp \
			--cap-add=NET_ADMIN monstrenyatko/rpi-openvpn-server

* Create the `TCP` configuration storage:

		OVPN_DATA_TCP="openvpn-server-data-tcp"
		docker volume create --name $OVPN_DATA_TCP

* Initialize the `TCP` configuration files:

		docker run -v $OVPN_DATA_TCP:/etc/openvpn --rm monstrenyatko/rpi-openvpn-server \
			ovpn_genconfig -u tcp://VPN.SERVER.DNS.NAME -n DNS.SERVER.IP -N \
			-e "push dhcp-option DOMAIN DOMAIN.NAME"

* Start `TCP` server process:

		docker run -v $OVPN_DATA_TCP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
			-v /etc/localtime:/etc/localtime \
			--name openvpn-server-tcp --restart unless-stopped -d -p 1194:1194/tcp \
			--cap-add=NET_ADMIN monstrenyatko/rpi-openvpn-server

## Backup

#### Certificates (PKI)

Backup archive `openvpn-pki.tar` will be created in current directory.

* Create:

		docker run -v $OVPN_DATA_PKI:/mnt --rm -v $(pwd):/backup hypriot/armhf-busybox \
			tar cvf /backup/openvpn-pki.tar -C /mnt .

* Cleanup and Restore:

		docker run -v $OVPN_DATA_PKI:/mnt --rm -v $(pwd):/backup hypriot/armhf-busybox \
			sh -c "find /mnt -mindepth 1 -delete"
		docker run -v $OVPN_DATA_PKI:/mnt --rm -v $(pwd):/backup hypriot/armhf-busybox \
			tar xvf /backup/openvpn-pki.tar -C /mnt

## Debugging Tips

* Check configuration:

		docker exec openvpn-server-udp cat /etc/openvpn/openvpn.conf

* Create an environment variable with the name DEBUG and value of 1 to enable debug output (using "docker -e").

		docker run -v $OVPN_DATA_UDP:/etc/openvpn -v $OVPN_DATA_PKI:/etc/openvpn/pki \
			--name openvpn-server-udp --restart unless-stopped -d -p 1194:1194/udp \
			--privileged -e DEBUG=1 \
			--cap-add=NET_ADMIN monstrenyatko/rpi-openvpn-server

* Test using a client that has OpenVPN installed correctly 

		$ openvpn --config CLIENT.NAME.VPN.SERVER.DNS.NAME.ovpn

* Run through a barrage of debugging checks on the client if things don't just work

		$ ping 8.8.8.8          # checks connectivity without touching name resolution
		$ dig google.com        # won't use the search directives in resolv.conf
		$ nslookup google.com   # will use search

## How Does It Work?

Initialize the Docker container using the `monstrenyatko/rpi-openvpn-server` image with the
included scripts to automatically generate:

- Diffie-Hellman parameters
- a private key
- a self-certificate matching the private key for the OpenVPN server
- an EasyRSA CA key and certificate
- a TLS auth key from HMAC security

The OpenVPN server is started with the default run cmd of `ovpn_run`.

The configuration is located in `/etc/openvpn`, and the Dockerfile
declares that directory as a volume.

Separate volume (mounted to `/etc/openvpn/pki`) holds the `PKI` keys
and certificates so that it could be backed up.

To generate a client certificate, `monstrenyatko/rpi-openvpn-server` uses EasyRSA via the
`easyrsa` command in the container's path. The `EASYRSA_*` environmental
variables place the PKI CA under `/etc/openvpn/pki`.

Conveniently, `monstrenyatko/rpi-openvpn-server` comes with a script called `ovpn_getclient`,
which dumps an inline OpenVPN client configuration file. This single file can
then be given to a client for access to the VPN.

To enable Two Factor Authentication for clients (a.k.a. OTP) see [this document](/docs/otp.md).

## OpenVPN Details

We use `tun` mode, because it works on the widest range of devices.
`tap` mode, for instance, does not work on Android, except if the device
is rooted.

The topology used is `net30`, because it works on the widest range of OS.
`p2p`, for instance, does not work on Windows.

The UDP server uses`192.168.255.0/24` for dynamic clients by default.

The client profile specifies `redirect-gateway def1`, meaning that after
establishing the VPN connection, all traffic will go through the VPN.
This might cause problems if you use local DNS recursors which are not
directly reachable, since you will try to reach them through the VPN
and they might not answer to you. If that happens, use public DNS
resolvers like those of Google (8.8.4.4 and 8.8.8.8) or OpenDNS
(208.67.222.222 and 208.67.220.220).


## Security Discussion

The Docker container runs its own EasyRSA PKI Certificate Authority. This was
chosen as a good way to compromise on security and convenience. The container
runs under the assumption that the OpenVPN container is running on a secure
host, that is to say that an adversary does not have access to the PKI files
under `/etc/openvpn/pki`. This is a fairly reasonable compromise because if an
adversary had access to these files, the adversary could manipulate the
function of the OpenVPN server itself (sniff packets, create a new PKI CA, MITM
packets, etc).

* The certificate authority key is kept in the container by default for
  simplicity. It's highly recommended to secure the CA key with some
  passphrase to protect against a filesystem compromise. A more secure system
  would put the EasyRSA PKI CA on an offline system (can use the same Docker
  image and the script [`ovpn_copy_server_files`](/docs/paranoid.md) to accomplish this).
* It would be impossible for an adversary to sign bad or forged certificates
  without first cracking the key's passphase should the adversary have root
  access to the filesystem.
* The EasyRSA `build-client-full` command will generate and leave keys on the
  server, again possible to compromise and steal the keys.  The keys generated
  need to be signed by the CA which the user hopefully configured with a passphrase
  as described above.
* Assuming the rest of the Docker container's filesystem is secure, TLS + PKI
  security should prevent any malicious host from using the VPN.


## Benefits of Running Inside a Docker Container

### The Entire Daemon and Dependencies are in the Docker Image

This means that it will function correctly (after Docker itself is setup) on
all distributions Linux distributions such as: Ubuntu, Arch, Debian, Fedora,
etc. Furthermore, an old stable server can run a bleeding edge OpenVPN server
without having to install/muck with library dependencies (i.e. run latest
OpenVPN with latest OpenSSL on Ubuntu 12.04 LTS).

### It Doesn't Stomp All Over the Server's Filesystem

Everything for the Docker container is contained in two Docker volumes:
configuration storage and `PKI` storage.
To remove it, remove the Docker images, volumes and corresponding containers
and it's all gone. This also makes it easier to run multiple servers since
each lives in the bubble of the container (of course multiple IPs or separate
ports are needed to communicate with the world).

### Some (arguable) Security Benefits

At the simplest level compromising the container may prevent additional
compromise of the server. There are many arguments surrounding this, but the
take away is that it certainly makes it more difficult to break out of the
container. People are actively working on Linux containers to make this more
of a guarantee in the future.

## Tested On

* Docker hosts:
  - Raspberry Pi 3:
     * Raspbian Jessie
     * Debian Package from [Docker Hypriot](https://hypriot.com) 1.10.3
* Clients
  - Android App OpenVPN Connect 1.1.17 (built 76)
     * OpenVPN core 3.0.12 android armv7a thumb2 32-bit
  - OS X El Capitan 10.11.6 with Tunnelblick 3.6.5 (build 4566)

## Having permissions issues with Selinux enabled?

See [this](docs/selinux.md)


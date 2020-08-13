---
section: 37
x-masysma-name: dashboards_with_docker
title: Grafana, Influxdb and Telegraf for System and Internet Monitoring
date: 2020/08/11 23:43:27
lang: en-US
author: ["Linux-Fan, Ma_Sys.ma (Ma_Sys.ma@web.de)"]
keywords: ["docker", "grafana", "telegraf", "influxdb", "telegraf", "monitoring", "dashboard", "linux", "internet", "performance"]
x-masysma-version: 1.0.0
x-masysma-repository: https://www.github.com/m7a/lo-madashdock
x-masysma-owned: 1
x-masysma-copyright: |
  Copyright (c) 2020 Ma_Sys.ma.
  For further info send an e-mail to Ma_Sys.ma@web.de.
---
Overview
========

This repository contains resources for building a local system monitoring
composed of the following components:

 * Grafana dashboards
    * _Few Systems_ dashboard to do basic Linux system monitoring
    * _Internet Connectivty_ dashboard to monitor connection outrages
    * _SMART_ dashboard to view HDD health information across systems
 * Influxdb database
 * Telegraf for metric acquisition
 * Docker for running the server-side components

This is largely running as-is at the Ma_Sys.ma. The following components might
be interesting in other contexts, too:

 * Configuration settings for running the services with Docker.
 * Dashboard configurations.

## System Composition

The idea of this repository is to provide sample configuration for the following
use case:

 * Centralized monitoring server (_server_)
 * Multiple clients sending metrics to the server (_clients_)

To do this, the server runs the following services as individual Docker
containers:

 * `grafana` -- Dashboard exposed on port 3000.
   Users intending to view the dashboards connect to this endpoint.
 * `influxdb` -- Database, only locally accessible
 * `telegraf-iconqualmon` -- Telegraf instance for acquiring Internet
   Connectivity metrics. May be left out if not needed.
 * `stunnel` -- TLS endpoint exposed on port 5086.
   Telegraf instances on the clients connect to this endpoint.

All of these services are defined in `server/docker-compose.yml`. All of their
configuration files are collected in directory `server`. Their connections among
each other could be visualized as follows:

    .             //////////////////////////////////////////////////////////////
                  //////////////////////////////////////////////////////////////
                  /////                                                    /////
         o        /////  Server-Side (running in containers)               /////
        _|_       /////                                                    /////
         |        /////  +------+---------+                                /////
        / \ ---> exposed   3000 | grafana |                                /////
      Client      /////  +------+---------+                                /////
      (User)      /////            ^                                       /////
                  /////            |                                       /////
                  /////  +------+----------+     +----------------------+  /////
                  /////  | 8086 | influxdb | <-- | telegraf-iconqualmon |  /////
    //////////    /////  +------+----------+     +----------------------+  /////
    //      //    /////            ^             (optional for Internet    /////
    // Cli- //    /////            |              connectivity monitoring) /////
    // ent  //    /////  +------+---------+                                /////
    //      ---> exposed   5086 | stunnel |                                /////
    // Tel- //    /////  +------+---------+                                /////
    // egr- //    /////                                                    /////
    // af   //    //////////////////////////////////////////////////////////////
    //////////    //////////////////////////////////////////////////////////////

The clients connect using Telegraf. System metrics are best acquired by running
on the actual system. Hence, Telegraf is run as a regular systemd service (not
in a Docker container).

Database connections are secured using TLS server and client certificates. As
Influxdb does not support client certificates directly, `stunnel` is used to
handle TLS traffic.

Each host will need individual configuration e.g. graphics card metrics may
not be available on all hosts, VMs will need different metrics compared to
physical systems etc. To address this need, a script to generate an installation
script for Telegraf is provided as `genclientinstaller.sh`. See section
_Client Installation_ for details.

Server Installation
===================

## TLS Configuration Preparation

Before running the server, necessary TLS certificates and keys need to be
gernated. Directory `scripts-tlsmanagement` contains some scripts to
simplify the process (a little).

The following certificates and keys are needed in the end:

 * CA private key (`ca.key`)
 * CA certificate (`ca.cer`)
 * Server certificate (`server.cer`)
 * Server private key (`server.key`)
 * Client certificate (`client.cer`)
 * Client pirvate key (`client.key`)

### 1. Configure Server Host IP

Proper TLS requires that certificates match the hosts they are created for.
`stunnel` can be configured to ignore this such that the individual clients do
not need their certificates to be tied to their hostnames or IP addresses. For
the server side, however, the server's hostname (or IP) needs to match whats
given in the certificate thus the first step is to write the server's IP
address to file `scripts-tlsmanagement/keys/extfile.cnf`. For instance, if
the server's address is 192.168.1.139, then configure the file as follows:

	subjectAltName = IP:192.168.1.139

### 2. Generate CA and Server Keys

Script `scripts-tlsmanagement/geninitialkeys.sh` generates the CA and server
keys and certificates using the following openssl commands:

~~~{.bash}
# set RSA strength in bits
strength=8192
# generate CA certificate
openssl req -nodes -newkey rsa:$strength -keyform PEM -keyout keys/ca.key -x509 -outform PEM -out keys/ca.cer
# generate server key
openssl genrsa -out keys/server.key $strength
# generate server certificate signing request
openssl req -new -key keys/server.key -out keys/server.req -sha256
# sign the server's key using the CA's certificate
openssl x509 -req -days 36500 -in keys/server.req -CA keys/ca.cer -CAkey keys/ca.key -CAcreateserial -outform PEM -out keys/server.cer -sha256 -extfile keys/extfile.cnf
~~~

All resulting keys are written to the `keys` directory. Note that expiry is set
to 100 years here to avoid monitoring from stopping due to key expiry. If you
consider it important, you can of course set a shorter validity.

### 3. Generate Client Key

Generate a client key using script `scripts-tlsmanagement/genclientkeys.sh`
which runs the following commands:

~~~{.bash}
# generate client key
openssl genrsa -out "keys/$clnt/client.key" "$strength"
# generate client certificate signing request
openssl req -new -key "keys/$clnt/client.key" -out "keys/$clnt/client.req"
# sign the client's key using the CA's certificate
openssl x509 -req -in "keys/$clnt/client.req" -CA keys/ca.cer \
			-CAkey keys/ca.key -extensions client -outform PEM \
			-out "keys/$clnt/client.cer"
~~~

### 4. Distribute Keys to the Server

By configuration from `stunnel.conf` and `docker-compose.yml`, the following
key files are required on the server:

 * `keys-server/server.key` -- the server's private key. Copy over from
   `scripts-tlsmanagement/keys`.
 * `keys-server/server-ca.cer` -- the server's certificate (`server.cer`)
   followed by the CA's certificate (`ca.cer`) concatenated in the same file.
 * `keys-server/allclients.cer` -- all of the clients' certificates concatenated
   into a single file.

A working set of files can be obtained by performing the following steps:

~~~{.bash}
# copy server's private key
cp keys/server.key ../server/keys-server
# assemble server's certificate among with the CA's certificate
cat keys/server.cer keys/ca.cer > ../server/keys-server/server-ca.cer
# assemble all client keys
cat keys/*/client.cer > ../server/keys-server/allclients.cer
~~~

## Password Configuration

Passwords can be configured either through environment variables or directly in
`docker-compose.yml`. To easily set the environment variables, create file
`server/.env` with contents of the following scheme (without the comments).

	GF_SECURITY_ADMIN_PASSWORD=password1         # Grafana password
	INFLUXDB_ADMIN_PASSWORD=password2            # Influxdb admin password
	INFLUXDB_READ_USER_PASSWORD=password3        # Influxdb read-only
	INFLUXDB_WRITE_USER_PASSWORD=password4       # Influxdb write-only
	MASYSMAWRITER_PASSWORD=password4
	MASYSMAREADER_PASSWORD=password3

Passwords `INFLUXDB_READ_USER_PASSWORD` and `MASYSMAREADER_PASSWORD` as well
as `INFLUXDB_WRITE_USER_PASSWORD` and `MASYSMA_READ_USER_PASSWORD` need to match
(otherwise database connectivity will fail).

## Internet Connectivity

If you want to use the _Internect Connectivity_ dashboard, be sure to configure
different URLs and servers in `server/iconqualnmon/telegraf.conf`

## Run

The containers can be started with `docker-compsoe` from directory `server`:

	# docker-compose up grafana influxdb stunnel

If you have configured the _Internet Connectivity_ settings in
`server/iconqualnmon/telegraf.conf` you can start all containers (i.e. including
the optional `telegraf-iconqualmon` service) with:

	# docker-compose up

By default, all data will be stored within the respective containers. While this
allows easy testing and cleanup, it also effectively disables persistence. Once
you intend to run the containers more permanently, edit `docker-compose.yml` and
enable the commented-out mappings from the `volumes` sections. Change the
host-side according to your local configuration and then re-create all
containers and this time run them with `docker-compse up -d` to run them in
background.

Client Installation
===================

If you are running the _Internet Connectivity_ dashboard, the server
installation may be enough. If you want to monitor individual systems, of
course, they need to run a local Telegraf instance to gather system metrics.

Script `scripts-clientmon/genclieninstaller.sh` is prepared to generate
installation scripts to be used to install the client on Debian systems. The
idea is to package all necessary key material, configuration and setup scripts
into a single “installer script” such that adding new clients is reasonably
easy.

Before using it, create a file `.env` next to `genclientinstaller.sh` with the
following conents:

~~~
keydir=".../clients/$1"
cacert=".../ca.cer"
MASYSMA_INFLUXDB=...
~~~

The dots need to be set according to your local file structure and network:

`keydir`
:   Set this to a directory where the key material for the current client can
    be found.
`cacert`
:   Set this to the `ca.cer` file's location
`MASYSMA_INFLUXDB`
:   Set this to the server's hostname where the Influxdb is running.

After this configuration, invoke

~~~
$ ./genclientinstaller.sh <client> > install-on-<client>.sh
~~~

to generate a setup script. This will include the key material and configuration
data to use on that client. Be sure to tweak the generated `telegraf.conf`
before running `install-on-<client>.sh` on the target machine as root.

Note: By its original package, Telegraf runs as a separate user. Given that it
might be interesting to also monitor Docker, however, it becomes necessary to
effectively give root permissions to Telegraf (either by adding it to the
`docker` group or by running it as root). If you do not want to monitor Docker
(or SMART or other things that require root), consider changing
`genclientinstaller.sh` accordingly.

Dashboards
==========

## Internet Connectivity

## Few Systems Overview

## HDD S.M.A.R.T Values

Additional Security Considerations
==================================

While the setup proposed here has some security, it is weak in at least
the following regards:

 * _All clients share the same client certificate_.
   `stunnel` documentation describes that it should be possible to provide
   _multiple_ client certificates in a CAfile, however this did not seem to
   work when tested. Only the first certificate listed was ever accepted. Hence
   the idea to use only one certificate at all. Another approach might be to use
   certificate directories (instead of a single file) which should allow for
   multiple client certificates.

 * _Grafana access is not secured_. To complete the secure setup, TLS access
   should be used for accessing the Grafana dashboards, too. While it is of
   less concern if the dashboards are expected to be publically viewable, it
   may still sometimes be needed to access the admin ínteraface and this access
   should be encrypted such that attackers cannot sniff the login information
   from packets transmitted over network.

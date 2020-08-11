# docker build -t arm32v7/masysmalocal/stunnel --build-arg=MDVL_CI_ARCH_PREFIX=arm32v7/ --build-arg=MA_DEBIAN_MIRROR=http://192.168.1.16/debian .
ARG	MDVL_CI_ARCH_PREFIX=
ARG	MDVL_CI_DEBIAN_VERSION=buster
FROM	debian:$MDVL_CI_DEBIAN_VERSION AS qemustatic
ARG	MDVL_CI_DEBIAN_VERSION=buster
ARG	MA_DEBIAN_MIRROR=http://ftp.de.debian.org/debian
SHELL	["/bin/sh", "-ec"]
RUN     :; \
	printf "%s\n%s\n%s %s\n" \
		"deb $MA_DEBIAN_MIRROR $MDVL_CI_DEBIAN_VERSION main" \
		"deb $MA_DEBIAN_MIRROR $MDVL_CI_DEBIAN_VERSION-updates main" \
		"deb http://security.debian.org/" \
					"$MDVL_CI_DEBIAN_VERSION/updates main" \
		> /etc/apt/sources.list; \
	apt-get update; \
	apt-get -y dist-upgrade; \
	apt-get -y install qemu-user-static;

ARG	MDVL_CI_ARCH_PREFIX=
ARG	MDVL_CI_DEBIAN_VERSION=buster
FROM	${MDVL_CI_ARCH_PREFIX}debian:$MDVL_CI_DEBIAN_VERSION
ARG	MDVL_CI_DEBIAN_VERSION=buster
LABEL	maintainer "Linux-Fan, Ma_Sys.ma <Ma_Sys.ma@web.de>"
LABEL	name masysmalocal/stunnel
ARG	MA_DEBIAN_MIRROR=http://ftp.de.debian.org/debian
SHELL	["/bin/sh", "-ec"]
COPY	--from=qemustatic /usr/bin/qemu-arm-static /usr/bin/qemu-arm-static
RUN     :; \
	printf "%s\n%s\n%s %s\n" \
		"deb $MA_DEBIAN_MIRROR $MDVL_CI_DEBIAN_VERSION main" \
		"deb $MA_DEBIAN_MIRROR $MDVL_CI_DEBIAN_VERSION-updates main" \
		"deb http://security.debian.org/" \
					"$MDVL_CI_DEBIAN_VERSION/updates main" \
		> /etc/apt/sources.list; \
	apt-get update; \
	apt-get -y full-upgrade; \
	apt-get -y install stunnel4; \
	apt-get clean; \
	:
USER stunnel4
CMD ["/usr/bin/stunnel4"]

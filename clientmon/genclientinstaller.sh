#!/bin/sh -e

keydir="/data/main/mdb/prod/keys/machines/sysmon/clients/$1"
MASYSMA_INFLUXDB=192.168.1.15

if [ $# = 0 ] || [ "$1" = "--help" ]; then
	echo "USAGE $0 <client> > install-on-client.sh"
	exit 1
fi

. "$(dirname "$0")/../.env"

cat <<ENDOFSCRIPT
#!/bin/sh -e
# auto-generated $(date) by $0
if ! aptitude search ~itelegraf > /dev/null; then
	aptitude update
	aptitude install telegraf
fi
mkdir /etc/telegraf/keys
MASYSMA_INFLUXDB=$MASYSMA_INFLUXDB
MASYSMAWRITER_PASSWORD=$MASYSMAWRITER_PASSWORD
cat > /etc/telegraf/telegraf.conf <<EOF
$(cat telegraf.conf)
EOF
cat > /etc/telegraf/keys/ca.cer <<EOF
$(cat "$keydir"/ca.cer)
EOF
cat > /etc/telegraf/keys/client.cer <<EOF
$(cat "$keydir"/client.cer)
EOF
cat > /etc/telegraf/keys/client.key <<EOF
$(cat "$keydir"/client.key)
EOF
chmod 600 /etc/telegraf/keys/*.cer /etc/telegraf/telegraf.conf
chmod 700 /etc/telegraf/keys
# systemctl enable telegraf
# systemctl start telegraf
ENDOFSCRIPT

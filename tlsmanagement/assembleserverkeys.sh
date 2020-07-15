#!/bin/sh -e
mkdir keys-server
cp keys/server.key keys-server
cat keys/server.cer keys/ca.cer > keys-server/server-ca.cer

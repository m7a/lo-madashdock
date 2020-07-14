#!/bin/sh -e
# https://www.makethenmakeinstall.com/2014/05/ssl-client-authentication-step-by-step/
strength=16384
openssl req -nodes -newkey rsa:$strength -keyform PEM -keyout keys/ca.key -x509 -outform PEM -out keys/ca.cer
openssl genrsa -out keys/server.key $strength
openssl req -new -key keys/server.key -out keys/server.req -sha256
openssl x509 -req -days 36500 -in keys/server.req -CA keys/ca.cer -CAkey keys/ca.key -CAcreateserial -outform PEM -out keys/server.cer -sha256 -extfile keys/extfile.cnf

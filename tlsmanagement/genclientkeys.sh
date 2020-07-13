#!/bin/sh -e

clnt="clnt_$(date +%s)_$$"
mkdir "keys/$clnt"
strength=16384
openssl genrsa -out "keys/$clnt/client.key" "$strength"
openssl req -new -key "keys/$clnt/client.key" -out "keys/$clnt/client.req"
openssl x509 -req -in "keys/$clnt/client.req" -CA keys/ca.cer \
			-CAkey keys/ca.key -extensions client -outform PEM \
			-out "keys/$clnt/client.cer"

#openssl pkcs12 -export -inkey "keys/$clnt/client.key" -in keys/client.cer "keys/$clnt/client.p12"

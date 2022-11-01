#!/bin/sh

# Generates a new CA and signed server/client keys, in this directory

echo -e "\nThe 'CommonName' must be unique for each new key,"
echo -e "or it will cause problems with verification\n"

# Generate certificate authority (ca-personal) key and then cert        
openssl genrsa 4096 > ca-personal.key 
openssl req -new -x509 -nodes -days 99999 -key ca-personal.key -out ca-personal.crt

# Generate server key; cert request; and then sign the cert with ca-authority
openssl req -newkey rsa:4096 -nodes -days 99999 -keyout server.key -out server-req.pem
openssl x509 -req -days 99999 -set_serial 01 -in server-req.pem -out server.crt -CA ca-personal.crt -CAkey ca-personal.key

# Generate client key; cert request; and then sign the cert with ca-authority
openssl req -newkey rsa:4096 -nodes -days 99999 -keyout client.key -out client-req.pem
openssl x509 -req -days 99999 -set_serial 01 -in client-req.pem -out client.crt -CA ca-personal.crt -CAkey ca-personal.key

# Verify both certs
openssl verify -CAfile ca-personal.crt ca-personal.crt server.crt
openssl verify -CAfile ca-personal.crt ca-personal.crt client.crt
  
# Last you must convert the key and cert into a combined file for Android
openssl pkcs12 -export -in client.crt -inkey client.key -out client-combined.p12

# Clean transient files and assign correct permissions
rm *.pem
chmod -R 444 *.crt
chmod -R 400 *.key
chmod -R 400 client-combined.p12



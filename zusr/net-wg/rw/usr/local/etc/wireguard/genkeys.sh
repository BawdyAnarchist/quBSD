#!/bin/sh

wg genkey > priv.key 
cat priv.key | wg pubkey > pub.key
chmod 600 priv.key

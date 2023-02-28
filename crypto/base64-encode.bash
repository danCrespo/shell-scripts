#!/usr/bin/env bash

echo "$1" | openssl sha256 - | openssl base64 -salt -e | tr -d '\n'

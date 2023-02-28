#!/usr/bin/env bash

openssl x509 -pubkey \
  -in "$1" | openssl rsa \
  -pubin \
  -outform der 2>/dev/null | openssl dgst \
  -sha256 -hex | sed 's/^.* //'

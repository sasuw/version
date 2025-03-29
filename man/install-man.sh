#!/usr/bin/env bash

sudo mkdir -p /usr/local/share/man/man1
sudo cp version.1 /usr/local/share/man/man1/version.1
sudo gzip /usr/local/share/man/man1/version.1
sudo mandb

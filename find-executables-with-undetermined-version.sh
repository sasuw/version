#!/usr/bin/env bash

find . -type f | sort | xargs -I{} version.sh -s "{}" | grep --line-buffered undetermined | tee version-undetermined-usr-bin.log

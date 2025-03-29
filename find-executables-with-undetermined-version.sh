#!/usr/bin/env bash

target_dir="${1}"
find "${target_dir}" -type f | sort | xargs -I{} version.sh -s "{}" | grep --line-buffered undetermined | tee ./version-undetermined-usr-bin.log

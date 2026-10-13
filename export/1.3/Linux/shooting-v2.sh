#!/bin/sh
printf '\033c\033]0;%s\a' shooting-v2
base_path="$(dirname "$(realpath "$0")")"
"$base_path/shooting-v2.x86_64" "$@"

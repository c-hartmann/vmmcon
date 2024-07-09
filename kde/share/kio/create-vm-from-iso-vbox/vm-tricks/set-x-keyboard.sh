#!/bin/bash
test -n "$1" || echo "argument required: lang code" && exit 1
setxkbmap $1


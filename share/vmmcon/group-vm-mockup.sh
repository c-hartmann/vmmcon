#!/bin/bash

# set -x
declare -a arr=("${@}")
declare -i len=${#arr[@]}

# arr=()
# while (($#)); do
# 	arr+=("$1")
# 	shift
# done

for ((n = 0; n < len; n++))
    do
        echo -en "|${arr[$n]}"
    done
echo "|"

_last=$(( len - 1 ))
echo $_last
_group_name="${arr[$_last]}"
echo $_group_name

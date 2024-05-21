#!/bin/bash

min=1028
max=32766
R1=$(($RANDOM%($max-$min+1)+$min))
R2=$(($RANDOM%($max-$min+1)+$min))
echo $R1
echo $R2
echo $((R1+R2))

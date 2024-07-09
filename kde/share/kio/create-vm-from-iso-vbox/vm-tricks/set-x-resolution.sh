#!/bin/bash
# vbox-xrandr-mode.sh

declare -a standard

# 4:3
# 800x600   (SVGA)
# 1024x768  (XGA)
# 1280x1024 (SXGA)
# 2048x1536 (QXGA)

standard[SVGA]="800x600"
standard[XGA]="1024x768"
standard[SXGA]="1280x1024"
standard[QXGA]="2048x1536"

# 16:9
# 1280x720  (WXGA)
# 1360x768  (HD)
# 1600x900  (HD+)
# 1920x1080 (FHD)
# 2048x1152 (QWXGA)

standard[WXGA]="1280x720"
standard[HD]="1360x768"
standard[HD+]="1600x900"
standard[1920x1080]="FHD"
standard[2048x1152]="QWXGA"

# 16:10
# 1280x800  (WXGA)
# 1440x900  (WXGA+)
# 1680x1050 (WSXGA+)
# 1920x1200 (WUXGA)

standard[WXGA]="1280x800"
standard[WXGA+]="1440x900"
standard[WSXGA+]="1680x1050"
standard[WUXGA]="1920x1200"

if [[ $1 =~ [A-Z4+] ]]; then
	# valid key?
	[[ -v ${standard[$1]} ]] || echo "display mode not existing: $1" >&2 && exit 1
	res="${standard[$1]}"
else
	res="$1"
fi

[[ $res =~ [0-9]+x[0-9]+ ]] || echo "display size non standard: $1" >&2 && exit 1
xrandr --output "Virtual1" --mode "$res" # --output default might also work


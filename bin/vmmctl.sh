#!/usr/bin/env bash

# vim: syntax=sh tabstop=4 softtabstop=0 expandtab shiftwidth=4 smarttab :

# this script requires minimum version 4 as of Bash on the 20th of February, 2009

### ###########################################################################

### script: vmmctl.sh
### create-vm-from-iso.sh (if installed a dolphin service menu this is a simple wrapper)
### author: hartmann.christian@gmail.com, c-hartmann@github.com, github.com/c-hartmann
### description: Creates a Virtual Machine from suitable ISO images or controls existing
### last update: 2023-04-25
### preferred places to live in:
### $HOME/.local/bin/
### $HOME/.local/share/kservices5/ServiceMenus/ (where the service menu wrapper goes)
### SPDX-FileCopyrightText: 2023 Christian Hartmann <hartmann.christian@gmail.com>
### SPDX-License-Identifier: LicenseRef-KDE-Accepted-GPL

### This program is free software; you can redistribute it and/or
### modify it under the terms of the GNU General Public License as
### published by the Free Software Foundation; either version 3 of
### the license or (at your option) at any later version that is
### accepted by the membership of KDE e.V. (or its successor
### approved by the membership of KDE e.V.), which shall act as a
### proxy as defined in Section 14 of version 3 of the license.

### This program is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
### GNU General Public License for more details.

### TODO : get true/false v. 0/1 consistent throughout this script
###        simple intuitive configuration outperforms niceclean code
###        create_stamp, create_desktop_menu_entry, create_desktop_menu_entry_native_command
### TODO :
### TODO :
### TODO :
### TODO :

### ###########################################################################

VERSION="0.1.42"

### by default this is not verbose
VERBOSE=false

### debugging might be enabled by exported environment variable (default to false)
DEBUG=${VMMCON_DEBUG:-false}; $DEBUG && set -x

### exit immediatly if a command exits with a non-zero status
### WARNING uncommenting won't allow kdialogs getting canceled
#set -o errexit

### treat undefined vars as errors and break if found
set -o nounset

### get exit status from a pipeline
set -o pipefail

### avoid to fail if no profile is installed
shopt -s nullglob

### allow case insensitive string comparisons (at least this will kill eval of options)
#shopt -s nocasematch

### do not override existing files with output redirection (just in case we did something totaly wrong)
set -o noclobber

### ensure running in a controlled (language) environment
#LANG=C

# TODO does this make any sence still? since we gave SHARE_PATH now?
# >    diabling here now. delete later...
### my installation directory
# BIN_DIR="$(dirname "$(readlink -m "$0")")"
# if [[ ! -d "${BIN_DIR}" ]]; then
# 	_error_exit "FATAL: not found BIN_DIR: ${BIN_DIR}. Giving up. ($LINENO)"
# else
# 	$VERBOSE && printf "running in ${BIN_DIR} [1]\n"
# fi

### reference to repository / wiki etc.
MY_GIT_HOME='https://github.com/c-hartmann/vmmctl.sh'

### me, myself and i
MY_NAME="vmmctl"
MY_NEW_NAME="vmmcon"
MY_PATH="${BASH_SOURCE[0]}"
MY_FILE="${MY_PATH##*/}"
MY_FILE="${MY_FILE%%.*}"

MY_SHARE_PATH="$HOME/.local/share/${MY_NEW_NAME}:$HOME/.${MY_NEW_NAME}:/usr/local/share:/usr/share"
### use first available in share path
# credit:
# to: https://stackoverflow.com/users/1815797/gniourf-gniourf
# in: https://stackoverflow.com/questions/11655770/looping-through-the-elements-of-a-path-variable-in-bash
IFS=: read -r -d '' -a path_array < <(printf '%s:\0' "$MY_SHARE_PATH")
for p in "${path_array[@]}"; do
    ### just use this, so we have a fallback path at least from last entry in path
    MY_SHARE="$p"
    [[ -d "$p" ]] && break
done

### desktop integration requires launchers build from these templates
# TODO switch to vmmcon inside these templates
VMMCTL_DESKTOP_ENTRY_TEMPLATE="desktop-entry-template.desktop"
VMMCTL_DESKTOP_MENU_TEMPLATE="desktop-menu-category.menu"
VMMCTL_DESKTOP_DIRECTORY_TEMPLATE="desktop-menu-category.directory"

### desktop Launcher (at least on KDE) does not respect commands in PATH
### until you configure it to do so
### try creating or editing $HOME/.config/plasma-workspace/env/path.sh
### see: https://userbase.kde.org/Session_Environment_Variables
# VMMCON_PATH_CANONICAL="$(readlink -f "$MY_PATH")"
# VMMCON_PATH_CANONICAL="$HOME/.local/bin/vmmcon"  # currently hard coded

# a usual shortcut
ME="${MY_NEW_NAME}"

### in qemu/libvirt world VMM is a wellknown synonym for 'Virtual Machine Manager'
### we shouldn't try to control this .. is to hijack this .. rename to VMC ? From
### a users perspective, his is what this actualy does!

# default title (for dialogs and such)
# MY_TITLE_NATIVE="Virtual Machine Manager Console"
# MY_TITLE="$MY_TITLE_NATIVE"
MY_TITLE="Virtual Machine Manager Console"

### command line $0 triggers either VMM, COMMAND or both...

# this is designed to live alongside with other vmms. differentiate them...
if [[ "${MY_FILE}" =~ ^.*-vbox$ ]]; then
	MY_TITLE="$MY_TITLE (VBox)"
	VMM='vbox'
fi

if [[ "${MY_FILE}" =~ ^.*-vmware$ ]]; then
	MY_TITLE="$MY_TITLE (VMware)"
	VMM='vmware'
fi
# QEMU/KVM separate? arent't these two sides of a coin?
# https://www.tecchannel.de/a/fuenf-beliebte-virtualisierer-fuer-linux-im-vergleich,3282102,3
# KVM läuft unter Linux als Kernel-Modul und benötigt Qemu zur Hardware-Emulation
# sowie einen SEPARATEN VM-MANAGER FÜR DIE KOMMANDOZEILE oder für die grafische Oberfläche.
if [[ "${MY_FILE}" =~ ^.*-libvirt$|^.*-qemu$ ]]; then
	MY_TITLE="$MY_TITLE (QEMU)"
	VMM='qemu' # ='libvirt,virsh' ?
fi

# depending in my command name / binary create might be a default
if [[ "${MY_FILE}" =~ ^create-.* ]]; then
	### but default mode is true (long: createfromiso)
	createfromiso=true
	### create is currently just a short cut to createfromiso (about to change)
	create=true
	### new command mode
	COMMAND='create'
fi

### warm welcome (and test of localization)
# printf "$(gettext 'Welcome to'): ${MY_TITLE} \n"
# printf "$(gettext 'Version'): ${VERSION}\n"
# printf "$(gettext 'Welcome to'): ${MY_TITLE} Version: ${VERSION}\n"
printf "${MY_TITLE} v${VERSION}\n"

### l10n
export TEXTDOMAIN="${MY_NAME}"
export TEXTDOMAINDIR="${MY_SHARE}/locale"
### execute the builtin script
. gettext.sh

### this is based on the idea of vm profiles and this is where they live
PROFILES_DIR="${MY_SHARE}/profiles"
PROFILES_DIR_LOCAL="${MY_SHARE}/profiles.local"

### a simple indexed global array holding profile names (including local ones)
# declare -a TEMPLATES

### second config level is distro names based (see slax.conf for example)
MATCHES_DIR="${MY_SHARE}/matches"

### virtual machine monitor function sets go into (called by vmm_name.sh)
VMMS_DIR="${MY_SHARE}/vmms"


# TODO VBOX_VM_PATH required (here)?
### where VBox generaly creates VMs and we store the disks in
vbox_default_machine_folder=$(VBoxManage list systemproperties | sed -n 's/^Default machine folder: *//pi')
# shellcheck disable=SC2034
VBOX_VM_PATH=${vbox_default_machine_folder:-$HOME/.VirtualBox/VMs}
[[ -d "$VBOX_VM_PATH" ]] || _error_exit "Couldn't determine default VM directory. All i have is: \"$VBOX_VM_PATH\". ($LINENO)"


### where all the profiles live. if you can't resists, you might create one for Window*
automagic_table="${MY_SHARE}/automagic.csv"
automagic_table_local="${MY_SHARE}/automagic.local.csv"

### desktop notifications will vanish after seconds
notification_timeout=4000

### by default info is key value pair styled
human_readable=false

### user configurable ISO images download directory
#iso_download_top_dir="$HOME/Downloads"

### initialize dialog type
declare gui
declare cli
if [[ ! -t 0 ]]; then
	# running via service menu
	gui=true
	cli=false
else
	# running from command line
	gui=false
	cli=true
fi

### we are started from context menu but run in terminal
terminal=false

### set some defaults so we do not fail on using these later
TODAY="$(date --iso-8601)"
STAMP=''

### every new VM name will be trailed by a STAMP based on current date
create_stamp=$(true)

### every new VM will be added to start menu system
create_desktop_menu_entry=$(true)
# create_desktop_menu_entry_native_command=$(false)

### filepath is expected to carry the full path to the ISO image
filepath=""

### running modes
auto=false
pwr=false
yes=false
dry=false
list_running=false
list_stopped=false

### vmm selector switch
vbox=true
libvirt=false
vmware=false
# kvm=false

### no default VM to operate on
VM=''

### commands instead of options.. (if after reading options first word is one of these)
#_default_command=create
#COMMAND=$_default_command
valid_commands=( \
	"clone" \
	"create" \
	"create-from-iso" \
	"create-desktop-entry" \
	"delete" \
	"delete-desktop-entry" \
	"remove-desktop-entry" \
	"export" \
	"help" \
	"import" \
	"info" \
	"install" \
	"move" \
	"launch" \
	"list" \
	"open" \
	"pause" \
	"query" \
	"readdocs" \
	"remove" \
	"rename" \
	"search" \
	"search-desktop-entry" \
	"snap" \
	"start" \
	"stop" \
	"state" \
	"status" \
	"view")

### the virtual machines name is vital throughout this script
vm_name=""

### match and profile are used to read lowercase named config files
declare -l match=""
declare -l profile=""


# TODO: move all "initernal" defaults to a default rc file? this could
#       easier serve the user as a list of options to copy to local rc

### a default VBox OS type to create (reset via profile file)
# TODO: this is VBox specific and should therefore reflect this in its naming:
#       e.g.: vbox_ostype=Linux or vm_vbox_ostype=Linux_64
#       current Linux *is* a 64 bit system and the right option for 99% of new
#       VMs, and therefore we should differentiate the 32 bit only from the
#       default case (i.e. 64 bit). So 'Linux' is appropriate for 64 bit
#       Linux32 for older systems.
vm_ostype=Linux_64

### set memory default values (and a fallback here) (THIS SHALL GO INTO A FILTER SECTION THAT CREATES REASONABLE SETTINGS FOR EVERY VM BY ISO NAME)
vm_memory_size=0
vm_memory_size_fallback=4096
vm_memory_size_divider=4

### these are internal defaults to determine the count of cpu core in the new VM
### both are available through the config files. by default the divider value is
### used to calculate the count for the vm from the physical host system.
### if vm_cpu_count is set to values greater than 0, this is used whatever the host
### might look like
vm_cpu_count=0
vm_cpu_count_divider=3

### set video memory defaults
vm_vram_size=128

### disk size (in GB)
# shellcheck disable=SC2034
vm_disk_size=40
vm_disk_count=1
vm_disk_type="vdi" # other: vdi (default), vhd (M$?), vmdk (smart altenative as readable also by qemu)
vm_disk_alloc="dynamic"

### Enable PAE/NX: Determines whether the PAE and NX capabilities of the host CPU will be exposed to the virtual machine
### (64 Bit system do make any use of it)
# shellcheck disable=SC2034
vm_pae="off" # default: "off"

### motherboard
### Be sure to enable I/O APIC for virtual machines that you intend to use in 64-bit mode. (https://www.virtualbox.org/manual/ch03.html)
vm_ioapic="on"
# shellcheck disable=SC2034
vm_chipset="piix3"
# shellcheck disable=SC2034
vm_firmware="bios" # bios|efi|efi32|efi64
# shellcheck disable=SC2034
vm_acpi="on" # default:  "on"
### clock (defaults to no utc clock)
vm_rtcuseutc="on"

### cpu
# see: https://www.it-swarm.com.de/de/virtualbox/wann-muss-ich-pae-nx-verwenden/944835828/
### there is no use of PAE for 64 bit guests
### in gereral you do not want to passthrough of hardware virtualization functions to the guest VM
vm_pae="off"
vm_nested_virt="off"

### VBox recommends to use VMSVGA graphics controller for Linux guests, so we do.
### VMSVGA: Use this graphics controller to emulate a VMware SVGA graphics device.
### This is the *default* graphics controller for Linux guests.
### unfortunately this comes with the essential limitation of 800x600 screen size
vm_gfx_controller="vmsvga" # default: "vmsvga", other: vboxvga, vboxsvga

### EFI screen resolutions (https://www.virtualbox.org/manual/ch03.html#efi)
### vm_efi_gfx_resolution="1920x1200" # WUXGA
### vm_efi_gfx_resolution="1280x1024" # SXGA
### more here: https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/efi.html
vm_efi_gfx_resolution="1280x800"  # WXGA

### most newer linux make use of 3D accelaration feature if present
### so we do (via $ME.conf although it defaults to off and requires
### guest additions being installed
vm_gfx_accelerate3d="off"

### support neted paging on vt enabled hosts only
vm_nestedpaging="off"
# vm_paravirtprovider="none"
vm_hypervisor="default"

### these are the defaults for Linux guests
# "ps2kbd" for keyboard?
# see: vboxmanage showvminfo --machinereadable $VM | grep -E 'hidkeyboard|hidpointing'
vm_hid_pointing="usbtablet"
vm_hid_keyboard="ps2"

### level of USB support at host
vm_usb="on"      # USB-1.1, default: "off"
vm_usbehci="off" # USB-2.0, default: "off" # incompatible vbox ext pack can prevent system
vm_usbxhci="off" # USB-3.0, default: "off" # from booting if usb 2 or 3 support is enabled

### audio
vm_audioout="on"
vm_audioin="off"
vm_audiocontroller="ac97"
vm_audiocodec="ad1980" # default in gui mode

### vbox allows custom graphics resolutions
declare -a vm_gfx_controller_resolutions

### execute the config file now as this might impact the calculation of cpu core
# CONF="${MY_DIST}/${MY_NAME}.conf"
# if [[ -f "$CONF" ]]; then
# 	# shellcheck disable=SC1090
# 	. "$CONF"
# fi
RC="${MY_SHARE}/${ME}rc"
if [[ -f "$RC" ]]; then
	# shellcheck disable=SC1090
	. "$RC"
fi
# NOTE: neither env::VMMCTL_VMM, nor config::vmm shall override VMM setting via file name
#       but VMMCTL_VMM shall override config::vmm
if [[ ! -v VMM ]]; then
	VMM=${VMMCTL_VMM:-$vmm}
fi




### _json_read_jq file object path
_json_read_jq ()
{
	local json_file="$1"; shift
	local jq_path="$(printf '.%s' $@)"
	jq -r "${jq_path}" < "$json_file"
}

### _json_read_p(ython)3 file object path
_json_read_p3 ()
{
	local json_file="$1"; shift
	local p3_path="$(printf '["%s"]' $@)"
	python3 -c "import sys, json; print(json.load(sys.stdin)${p3_path})" < "$json_file"
}

### _json_read file object path
_json_read ()
{
	if [[ $jq ]]; then
		_json_read_jq $@
	elif [[ $p3 ]]; then
		_json_read_p3 $@
	else
		echo ERROR
		exit 99
	fi
}

### _strip # string
_strip ()
{
	local _string="$1"
	_string="${_string## }"
	_string="${_string%% }"
	printf '%s' "${_string}"
}

### _notify
### wrapper that respects gui or cli mode
_notify ()
{
	$gui && notify-send --app-name="${MY_TITLE}" --icon=virtualbox --expire-time=$notification_timeout "$@"
	$cli && printf "\n%s\n" "$@" >&2
}

### _error_exit
### even more simple error handling
_error_exit ()
{
	local error_str="$(gettext "ERROR")"
	$gui && kdialog --error "$error_str: $*" --ok-label "So Sad"
	$cli && printf "\n%s: %s\n\n" "$error_str" "$1" >&2
	exit ${2:-1}
}

### _canceled_exit
_canceled_exit ()
{
	_notify "canceled"
	exit 1
}

### _warning
_warning ()
{
	if $gui; then
		kdialog --warningcontinuecancel "WARNING: $*"
		return $?
	else
		printf "\n" >&2
		read -p "WARNING: ${*}. Continue? [N/y] "
		REPLY="$(_strip "$REPLY")"
		[[ $REPLY =~ yY ]] && return 0
		[[ -z $REPLY ]] && return 1
		return 0
	fi
}

### _debug - print debug messages if in DEBUG mode
_debug ()
{
	$DEBUG && printf "$@\n" >&2
}

### _debug - print debug messages if in DEBUG mode
_verbose ()
{
	$VERBOSE && printf "$@\n" >&2
}

### _get_config <config name>
### return <config value>
_get_config ()
{
	local _cn="$1"
	eval printf '%s' "\$$_cn"
}

### _user_file_path - ask userin for path to image file
_user_file_path ()
{
	local _dir="$1"
	local _fp
	local _fn
	if $gui; then
		_fp=$(kdialog --getopenfilename "$_dir" "application/x-cd-image" 2>/dev/null)
		printf "$_fp"
	else
		# TODO replace 'which' by either 'type' or 'command'
		if which mimetype >/dev/null ; then
			printf "looking for ISO images by mime type (application/x-cd-image). this will take some time...\n" >&2
			printf "\n" >&2
			( cd "$_dir"; find . -type f -exec bash -c "mimetype \"{}\" | grep -q application/x-cd-image" \; -print | sed 's#^./##' | sort >&2 )
		else
			( cd "$_dir"; find . *.iso *.ISO | grep -e '.iso$' | sed 's#^./##' | sort >&2 )
		fi
		printf "\n" >&2
		read -t 20 -p "Enter one of the filenames above (within 20 seconds): "
		REPLY="$(_strip "$REPLY")"
		_verbose "YOUR REPLY: '${REPLY:-none}'" >&2
 		[[ -z "$REPLY" ]] && return 1
 		_fn="$REPLY"
		printf "$_dir/$_fn"
	fi
}

### _auto_profile - get profile to use from local andd global match profile table
_auto_profile ()
{
	local filename="$1"
	local matchtbl="$2"
	local temp=$(mktemp)
	local match
	local profile
	_verbose "getting profile by: $filename" >&2
	_verbose "reading match table: $matchtbl" >&2
	ifs=';:,.'
	### for every first word in line match case insentive to image file name
	### on match use second word as profile name
	### check for existence of found profile (just in case we have done wrong in the list)
	### be case insensitive for this search
	shopt -s nocasematch
	### allow output redirection to existing files temporaly
	set +o noclobber
	# shellcheck disable=SC2034
	cat "$matchtbl" | sed 's/#.*//' | sed '/^[[:space:]]*$/d' > $temp
	while IFS=$ifs read -r match profile dump; do
		if [[ "$filename" =~ .*$match.* ]]; then
			_verbose "MATCHED BY: $match" >&2
			_verbose "PROFILE IS: $profile" >&2
			break
		fi
	done < $temp
	set -o noclobber
	shopt -u nocasematch
	unset dump
	rm $temp
	printf '%s %s' "$match" "$profile"
}

### _user_profile - ask userin on profile to base vm on
_user_profile ()
{
	### build up a list of available profiles
	declare -A profile_select_list
	declare -a profile_select_list_helper
	i=1 ### NOTE the helper array will start with index 1
	for conf in "${PROFILES_DIR}"/*.conf "${PROFILES_DIR_LOCAL}"/*.conf; do
		name="UNKNOWN"
		. "$conf"
		# get simple tag from path to config file
		tag="${conf%.conf}"
		tag="${tag##*/}"
		### add to Array if not already in
		if [[ ! -v profile_select_list[$tag] ]]; then
			profile_select_list[${tag}]="$name"
			profile_select_list_helper[$i]="$tag"
			((i++))
		fi
	done
	if $gui; then
		kdialog_radiolist_tag_item_list=" "
		for tag in ${!profile_select_list[*]}; do
			### WARNING
			### NEXT LINE WILL FAIL, IF $name HAS SPACES IN IT
			kdialog_radiolist_tag_item_list+="$tag ${profile_select_list[$tag]} off "
		done
		profile=$(kdialog --title "$MY_TITLE" --radiolist "Select profile  to use:" $kdialog_radiolist_tag_item_list)
		printf "$profile"
	else # (cli)
		select=''
		i=1
		declare -u opt
		printf "\n" >&2
		printf "Choose profile...\n" >&2
		printf "\n" >&2
		printf "A) AUTOMAGICALLY\n" >&2
		for i in ${!profile_select_list_helper[*]}; do
			tag="${profile_select_list_helper[$i]}"
			printf "$i) ${profile_select_list[$tag]}\n" >&2
			((i++))
		done
		printf "C) CANCEL ALL\n" >&2
		printf "\n" >&2
		read -t 10 -p "Choose profile by number as above, Automagically or Cancel [A/c] "
		REPLY="$(_strip "$REPLY")"
 		[[ -z "$REPLY" ]] && REPLY='A' # just assume Automatically on empty REPLY
 		[[ $REPLY =~ [Cc] ]] && return 1
# 		### valid cancel options are none, x, X
		valid_reply_pattern="[AaCc0-9]+"
#		[[ $REPLY =~ $valid_reply_pattern ]] && _verbose "Valid REPLY" >&2
		[[ $REPLY =~ $valid_reply_pattern ]] || printf "NO valid REPLY: $REPLY\n" >&2
		[[ $REPLY =~ $valid_reply_pattern ]] || return 1
		### get it automagically?
		if [[ $REPLY =~ [Aa] ]]; then
			_verbose "choosing profile auto magically..." >&2
			# try local match table first
			if [[ -f "$automagic_table_local" ]]; then
				read match profile < <(_auto_profile "$filename" "$automagic_table_local")
			fi
			# no luck with local table? try global
			if [[ -z "$profile" ]]; then
				read match profile < <(_auto_profile "$filename" "$automagic_table")
			fi
			_verbose "choosen profile: $profile" >&2
			printf '%s' "$profile" # return to sender
		else
			### REPLY shall not be less than 1
			[[ $REPLY -lt 1 ]] && printf "REPLY out of range: $REPLY\n" >&2
			[[ $REPLY -lt 1 ]] && return 1
			### REPLY shall not be greater than last index
			[[ $REPLY -ge $i ]] && printf "REPLY out of range: $REPLY\n" >&2
			[[ $REPLY -ge $i ]] && return 1
			### any not existing hash in array will trigger cancel in caller
			opt=$REPLY
			p=${profile_select_list_helper[$opt]}
			printf "choosen: '${profile_select_list[$p]}'\n" >&2
			_verbose profile_select_list_helper[$opt]=${profile_select_list_helper[$opt]} >&2
			printf '%s' "${profile_select_list_helper[$opt]}" # return to sender
		fi
	fi
}

### _get_host_memory_size - get memory size of physical (aka host) system
_get_host_memory_size ()
{
	local host_memory_size_kilobytes=$(grep MemTotal < /proc/meminfo | grep -o '[[:digit:]]*') # or: awk '{print $2}'
	printf "$(( host_memory_size_kilobytes / 1024 ))"
}

# # _vbox_manage - wrapper on VBoxManage that respects dry mode
# _vbox_manage ()
# {
# 	[[ $1 = $# ]] || _error_exit "actual argument count ($#) does not match given argument count ($1) ($LINENO)"
# 	shift 1
# 	printf '%s\n' "VBoxManage $*" >&2
# 	$dry || VBoxManage "$@"
# }

### _get_vm_name - wrapper that asks userin for vm's name
_get_vm_name ()
{
	local _vm_name_suggest="$1"
	local _vm_name
	local _spacer="                                          " # create a wider dialog
	if $gui; then
		_vm_name=$(kdialog --title "${MY_TITLE}" --icon=question --inputbox  "Name of virtual machine to create:$_spacer" "$_vm_name_suggest")
	else
		printf "\n" >&2
		read -p "Name of virtual machine to create:  " -e -i "$_vm_name_suggest "
		REPLY="$(_strip "$REPLY")"
		if [[ -z "${REPLY}" ]]; then
			_vm_name="$_vm_name_suggest"
		else
			_vm_name="${REPLY}"
		fi
		printf "\n" >&2
	fi
	printf "${_vm_name}\n"
}

### _yes_no - wrapper that respects gui or cli mode
_yes_no ()
{
	_prompt="$1"
	_yes_label="$2"
	_no_label="$3"
	if $gui; then
		return $(kdialog --title "${MY_TITLE}" --icon=question --yesno "${_prompt}" --yes-label "$_yes_label" --no-label "$_no_label")
	else
		printf "\n" >&2
		read -p "$_prompt [Y/n] "
		REPLY="$(_strip "$REPLY")"
		[[ $REPLY =~ ^$ ]] && return 0
		[[ $REPLY =~ [yY] ]] && return 0
		return 1
	fi
}

_init_vm_cpu_count ()
{
	local _host_cpu_count
	local _vm_cpu_count
	### things to determine by parent host (a third of actual cpu cores is
	### acceptabel and our default on computation)
	### grepping on processor would return physical/real cores, vmx also counts virtual cores
	_host_cpu_count=$(grep -Ec '(vmx|svm)' /proc/cpuinfo) # if no output, host either so not support virtualization or it isn't enabled. bummer
	printf 'host cpu count: %s\n' "$_host_cpu_count" >&2
	### 0 enables dynamic count
	if (( vm_cpu_count == 0 )); then
		printf '%s' "computing count of virtual cpus..." >&2
		if (( _host_cpu_count > 0 )); then
			vm_nestedpaging="on" # defaults to on (i.e. using host cpu vt technology)
			vm_paravirtprovider="kvm" # kvm is default for Linux guests
			### compute a reasonable count for the count of guest cpu cores
			_vm_cpu_count=$(( _host_cpu_count / vm_cpu_count_divider ))
		else
			_vm_cpu_count=1
		fi
		printf "\b\b\b to: %s\n" "$_vm_cpu_count" >&2
	else
		printf 'using fixed count of virtual cpus: %s\n' "$vm_cpu_count" >&2
		_vm_cpu_count=$vm_cpu_count
	fi
	printf '%u' $_vm_cpu_count
}

_init_vm_memory_size ()
{
	local _host_memory_size
	local _vm_memory_size
	_host_memory_size=$(_get_host_memory_size)
	if (( vm_memory_size == 0 )); then
		printf "computing amount of virtual memory..." >&2
		if (( _host_memory_size > 0 )); then
			_vm_memory_size=$(( _host_memory_size / vm_memory_size_divider ))
		else
			_vm_memory_size=$vm_memory_size_fallback
		fi
		printf '\b\b\b to: %s\n' "$_vm_memory_size" >&2
	else
		printf "using fixed amount of virtual memory: $vm_memory_size\n" >&2
		_vm_memory_size=$vm_memory_size
	fi
	printf '%u' $_vm_memory_size
}

### _usage
### dead simple usage help on command line use
_usage ()
{
	cat << ____USAGE

    usage: ${MY_FILE} <command> [options] [<iso-image-file> | <vm-name> | <pattern>]

    commands:

      list                      list all VMs (for set or given VMM only)
      create <ISO>              create a new VM from ISO by [Options]

      info <VM>                 show infos of VM
      status <VM>               show status of VM

      start <VM>                start existing VM by its exact name
      stop <VM>                'pause' VM. (i.e. save state and close VM)

      rename <VM> <VM>          rename a VM
      clone <VM> <VM>           create a copy of an existing VM by its name
      delete <VM>               delete an existing VM by its exact name

      export <VM>               export an existing VM by its name as Appliance
      import <APP> [<VM>]       import a new VM from an application container  # TODO use VM name / Auto name?

      create-desktop-entry <VM> create a desktop entry for a VM
      delete-desktop-entry <VM> delete that one

      query <PATTERN>           search for VMs with names matching <PATTERN>

      help                      shows help (on command line)
      readdocs                  open the documentation in default browser

    options on creation of a new vm:

      -a | --auto               determine the profile auto-magically
      -d | --dry-run            dry run - do not create anything
      -f | --from               different approach to set ISO image file name
      -n | --name               name the machine to create
      -o | --option             set option by it's name as in foo=bar
      -p | --profile <profile>  a profile to use
      -s | --stamp <stamp>      append <stamp> instead of TODAY to vm name
      -u | --power-up           power up the VM after creating one
      -y | --yes                assume yes to all interactive questions

    if no image file is given but required, it will be requested interactively

      --vmm=<VMM>               use VMM as VMM
      --vbox                    use VirtualBox as VMM
      --qemu                    use QEMU/libvirt/VMM as VMM

    generic options:

      -h | --help               show this help
      -g | --force-gui          force GUI mode from terminal
           --human              human readable info command
      -v | --verbose            turn on verbose mode
      -V | --version            print the version and exit

____USAGE
}

# --------------------------------------
# create a simple name from a complex one to utilize in filenames
_get_simple_name ()
{
	### TODO: check result (on being niot empty) before returning?
	# replace spaces with underscores, strip '(' and ')'
	local _complex_name="$1"
	printf '%s' "$_complex_name" | sed 's/[ !$/\.]/_/g' | sed 's/[()]//g'
}

# --------------------------------------
# ensure we have a valid 'directory-file' (i.e. submenu) inside the menu structure
_init_directory_entry ()
{
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"
	local _xdg_menus_directory="$HOME/.config/menus/applications-merged"
	local _xdg_directories_directory="$HOME/.local/share/desktop-directories"
	local _xdg_desktop_menu_command="$(type -p xdg-desktop-menu)"

	_source="${MY_SHARE}/templates/xdg/${VMMCTL_DESKTOP_MENU_TEMPLATE}"
	_target="${_xdg_menus_directory}/${_my_vendor_prefix}.${VMMCTL_DESKTOP_MENU_TEMPLATE}"
	if [[ ! -f "${_target}" ]]; then
		cat "${_source}" > "${_target}"
	fi

	_source="${MY_SHARE}/templates/xdg/${VMMCTL_DESKTOP_DIRECTORY_TEMPLATE}"
	_target="${_xdg_directories_directory}/${_my_vendor_prefix}.${VMMCTL_DESKTOP_DIRECTORY_TEMPLATE}"
	if [[ ! -f "${_target}" ]]; then
### xdg-desktop-menu CAN NOT INSTALL A DIRECTORY FILE ON IT'S OWN! WHY EVER
### so we leave this code here until we know wtf is going on :)
### 		if [[ -n "$_xdg_desktop_menu_command" ]] ; then
### 			$_xdg_desktop_menu_command install --mode user "${_source}"
### 		else
			cat "${_source}" > "${_target}"
### 		fi
	fi
}

# --------------------------------------
# create a new entry in desktop start menu (such as kickoff)
# TODO check disabling flags here
_create_desktop_entry () # $VM
{
	local _vm="$1"
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"

	_init_directory_entry

# 	if [[ $create_desktop_menu_entry_native_command ]]; then
# 		# use VMM template with native command set and function
# 		vmms::create_desktop_entry "$_vm"  # <---- THIS IS NOT A VMM THING!
# 	else
		# use global template with my command set
		_template_file="${MY_SHARE}/templates/xdg/${VMMCTL_DESKTOP_ENTRY_TEMPLATE}"
		_template_content="$(cat "$_template_file")"
		### TODO: there are actualy two of these! there is also: ~/.gnome/apps/
		###       with a copy of my file, when created via xdg-desktop-menu(1).
		###       So we might either go for both directories and we might try
		###       xdg-desktop-menu(1) first and if this fails create manualy.
		# temporary file name to create
		_application_desktop_dir="${HOME}/.local/share/applications/${MY_NEW_NAME}"
		#_application_desktop_dir_gnome="${HOME}/.gnome/apps"
		_application_desktop_file="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
		_application_desktop_path="${_application_desktop_dir}/${_application_desktop_file}"
		# create file from template
		VM="$_vm"
		eval "echo \"${_template_content}\"" > "/tmp/${_application_desktop_file}"

# 		running internal command: create-desktop-entry Pop!_OS 21.04
# 		xdg-desktop-menu: filename 'org.vmmctl.vm.Pop__OS_21_04.desktop' does not have a proper vendor prefix
# 		A vendor prefix consists of alpha characters ([a-zA-Z]) and is terminated
# 		with a dash ("-"). An example filename is 'example-org.vmmctl.vm.Pop__OS_21_04.desktop'
# 		Use --novendor to override or 'xdg-desktop-menu --manual' for additional info.
		_xdg_desktop_menu_command="$(type -p xdg-desktop-menu)"
		if [[ -n "$_xdg_desktop_menu_command" ]] ; then
			$_xdg_desktop_menu_command 'install' '--novendor' "/tmp/${_application_desktop_file}"
		else
			cat "/tmp/${_application_desktop_file}" > "${_application_desktop_path}"
			rm "${_temp}"
		fi
		rm "/tmp/${_application_desktop_file}"
# 	fi
}

# --------------------------------------
# delete a formerly created entry in desktop start menu
_delete_desktop_entry () # $VM
{
	local _vm="$1"

	local -l _my_vendor_prefix="org.${MY_NAME}" # fixed(!) name: vmmctl

	### TODO: there are actualy two of these! there is also: ~/.gnome/apps/
	###       with a copy of my file, when created via xdg-desktop-menu(1).
	###       So we might either go for both directories and we might try
	###       xdg-desktop-menu(1) first and if this fails create manualy.
	# temporary file name to create
	_application_desktop_dir="${HOME}/.local/share/applications/vmmctl"
	#_application_desktop_dir_gnome="${HOME}/.gnome/apps"
	_application_desktop_file="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
	_application_desktop_path="${_application_desktop_dir}/${_application_desktop_file}"
	if [[ -f "${_application_desktop_path}" ]]; then
		_xdg_desktop_menu_command="$(type -p xdg-desktop-menu)"
		if [[ -n "$_xdg_desktop_menu_command" ]] ; then
			$_xdg_desktop_menu_command 'uninstall' "${_application_desktop_file}"
		else
			rm -f "${_application_desktop_path}"
		fi
	else
		echo "application desktop file does not exists: ${_application_desktop_path}" >&2
	fi
}

# --------------------------------------
# delete a formerly created entry in desktop start menu
_search_desktop_entry () # $VM
{
	local _vm="$1"
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"
	_application_desktop_dir="${HOME}/.local/share/applications/vmmcon"
# 	_application_desktop_file="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
	find "${_application_desktop_dir}" -name "${_my_vendor_prefix}.vm.*${_vm}*.desktop"
}

# --------------------------------------
# Run a command as given on command line
_run_command ()
{
	### commands are single words only
# 	local _command=$1
# 	local _param=''
# 	test $# -gt 1 && _param="$2"
# 	shift # command
# 	test $# -gt 1 && _param2="$2"
# 	shift # command
	# TODO neuer Ansatz: while (($#)); do
	#      und damit ein Array _params oder _argv füllen
	#      ARRAY+=("foo")
	#      ARRAY+=("bar")
	#      ARRAY+=("$1"); shift
	#      Nutzung: ${_argv[1]} ...
	#      _command=${_argv[0]}
	local _argv=()
	while (($#)); do
		_argv+=("$1")
		shift
	done
	_command=${_argv[0]}
	# TODO are multiple statements of the same case allowed? this could be used
	#      to put all the startup parts into a common one for clone, import, create
	# TODO sort commands by name to find them easier
	case $_command in
		clone )
			_cloned=1
			_vm="${_argv[1]}"
			_vm_clone="${_argv[2]}"
			[[ -n $_vm ]] || _error_exit "no existing vm name given ($LINENO)"
			[[ -n $_vm_clone ]] || _error_exit "no new vm name given ($LINENO)"
			[[ $_vm == $_vm_clone ]] || _error_exit "new vm name equals the source name ($LINENO)"
			vmms::vm_exists "${_vm}" || _error_exit "this VM does not exist: ${_vm} ($LINENO)"
			# TODO: stopped is a minimum requirement. as the new VM will be
			#       assigned a new MAC it *shall* be not only rebooted, but powered
			#       of and on to get the new MAC addr applied to the OS as well.
			#       Cloning a stopped (i.e. "saved state") VM will create a clone
			#       with the same state. Starting this new clone, will not make it
			#       realizing the new MAC address and therefore ensure conflicts
			#       with the cloned system, as both are sharing the same MAC.
			#       Therefore a powered off VM is way more fool proove
			vmms::vm_is_powered_off "${_vm}" || _error_exit "can not clone a running VM: ${_vm} ($LINENO)"
			printf '%s\n' 'cloning may take a while. Be patient...'
			vmms::clone_vm "${_vm}" "${_vm_clone}" && _cloned=0 # IF we do! have a clone name we use it in the vmm spec. part
			if (( $_cloned == 0 )); then
				_create_desktop_entry "${_vm_clone}" # "global" (set in vmms::clone_vm())
			fi
			### power this up?
			if ! $pwr; then
				if _yes_no "New VM added: '${_vm_clone}'. Power up now?" "Power Up" "Not Yet"; then
					pwr=true
				fi
			fi
			if $pwr; then
				vmms::start_vm "${_vm_clone}"
# 			else
# 				_notify "New VM not started"
			fi
			_exit=$_cloned
			_return=$_cloned
		;;
		create-desktop-entry )
			_created=1
			# TODO: this shall not create desktop entries for non existing machines
			# TODO exit if argument is not given (is this handled elsewehere? i guess not!
			$dry || _create_desktop_entry "${_argv[1]}" && _created=0
			_exit=$_created
			_return=$_created
		;;
		create | create-from-iso )
			_created=1
			### if filepath not set via option -f, use first argument instead
			if [[ -z "$filepath" ]]; then
				# TODO next test does not work as expectet :(
				if [[ -n "${_argv[1]}" ]]; then
					filepath="${_argv[1]}"
					_verbose "filepath=$filepath (by \$1)"
					shift 1
				fi
			fi
			# TODO this shall go into a function
			### still no file path? ask user
			if [[ -z "$filepath" ]]; then
				for dir in "$iso_download_top_dir" "$HOME/Downloads" "$HOME/Download" "$HOME" "/tmp" ; do
					if [[ -d "$dir" ]]; then
						_verbose "asking for iso file path..." >&2
						filepath=$(_user_file_path "$dir")
						[[ -n "$filepath" ]] || _canceled_exit
						_verbose \$filepath=$filepath "[by user dialog]"
						break
					fi
				done
			fi
			### still no file path? > fail
			if [[ -z "$filepath" ]]; then
				_error_exit "No ISO image file path given. Giving up. ($LINENO)"
			fi
			### check if we have anyfile and fail if not
			if [[ ! -f "$filepath" ]]; then
				_error_exit "Unsupported command or specified ISO image file path does not exist:  $filepath. Giving up. ($LINENO)"
			fi
			# TODO this shall go into a function: _check_file_on_mime_type $file $mimetype
			### check on right mime type
			# TODO replace 'which' by either 'type' or 'command'
			xdg_mime=$(which xdg-mime)
			if [[ -n "$xdg_mime" ]]; then
				printf '%s\n' "checking mime type..." >&2
				mime_type=$($xdg_mime query filetype $filepath 2>/dev/null)
				[[ "$mime_type" =~ application/x-cd-image ]] || _error_exit "Specified ISO file path does not fulfil mime type requirement: 'application/x-cd-image'. Giving up ($LINENO)"
			fi
			### check if we have a valid ISO file and fail if not
			# TODO replace 'which' by either 'type' or 'command'
			isovfy=$(which isovfy)
			if [[ -n "$isovfy" ]]; then
				printf '%s\n' "veryfying iso image..." >&2
				$isovfy $filepath >/dev/null 2>&1 || _error_exit "Specified ISO file path could not be veryfied as a valid ISO image. Giving up ($LINENO)"
			fi
			### use filename as in filepath to search for a profile
			filename=${filepath##*/}
			_verbose filename=$filename
			### inform the user*in"
			if [[ $yes = true ]]; then
				:
			else
				if ! _yes_no "Create Virtual Machine from \"$filename\"?" "Create" "Cancel"; then
					_canceled_exit
				fi
			fi
			### create a simple suggestion for the vm name from ISO image file name
			vm_name_suggest="${filename%.*}"
			vm_name_suggest="${vm_name:-$vm_name_suggest}"
			_verbose "STAMP=$STAMP" >&2
			if $create_stamp; then
				if [[ -n "$STAMP" ]]; then
					vm_name_suggest="${vm_name_suggest} (${STAMP})"
				else
					vm_name_suggest="${vm_name_suggest} (${TODAY})"
				fi
			fi
			_verbose "vm_name_suggest=$vm_name_suggest" >&2
			### get a name for the new virtual machine
# 			if [[ $yes = true ]]; then
			if $yes ; then
				vm_name="$vm_name_suggest"
			else
				# unfortunately kdialog --imginputbox does not respect additional preset text as --inputbox does,
				# so we can not use a nice icon here: "$BIN_DIR/${MY_NAME}.d/icons.d/display-and-tower.svg"
				# extra spaces trainling the proposed text are required as kdialog does not respect the text length
				if ! vm_name=$(_get_vm_name "$vm_name_suggest"); then
					_canceled_exit
				fi
			fi
			### check existence if vm name was given on command line
			vmms::vm_exists "$vm_name" \
				&& _error_exit "vm already exists: \"$vm_name\". Giving up. ($LINENO)"
			### automagic profile search (if set)
			if [[ -z "$profile" ]]; then
				if $auto; then
# _auto_profile "$filename" "$automagic_table" >&2
					if [[ -f "$automagic_table_local" ]]; then
						read match profile < <(_auto_profile "$filename" "$automagic_table_local")
					fi
					if [[ -z "$profile" ]]; then
						read match profile < <(_auto_profile "$filename" "$automagic_table")
					fi
				fi
				if [[ -z "$profile" ]]; then
					printf '%s\n' "auto profile match failed" >&2
				fi
			fi
			### if no templete given and auto false we ask the userin for a profile
# 			if [[ -z "$profile" && $auto = false ]]; then
			if [[ -z "$profile" ]]; then
				### ask user what profile to use or cancel
				profile=$(_user_profile)
				### no profile? userin has canceled
				test -n "$profile" || _canceled_exit
			fi
			### fallback to linux profile if we fail so far
# 			if [[ -z "$profile" ]]; then
#  				profile="linux"
# 			fi
			### neither profile or match .. give up
			if [[ -z "${profile}"  && -z "${match}" ]]; then
				_error_exit "No profile, must quit ($LINENO)" 9
			fi
			### be informative if wanted
			[[ -n $match ]] && printf 'using match: %s\n' "$match" >&2
			[[ -n $profile ]] && printf 'using profile: %s\n' "$profile" >&2
			### run profile config file, if it is there, warn on failure if not
			conf="${PROFILES_DIR}/${profile}.conf"
			if [[ -f "$conf" ]]; then # TODO reverse test to ! and save code lines
				printf '%s\n' "using profile config: $conf" >&2
				# shellcheck disable=SC1090
				. "$conf"
# 			else
# 				_warning "profile does not exist: '$conf'. Continue with fallback 'linux'?" || _canceled_exit
# 				conf="${PROFILES_DIR}/linux.conf"
# 				if [[ -f "$conf" ]]; then
# 					printf '%s\n' "running fallback config: $conf" >&2
# 					# shellcheck disable=SC1090
# 					. "$conf"
# 				fi
			fi
			### run local profile config file, if it is there
			local_conf="${PROFILES_DIR_LOCAL}/${profile}.conf"
			if [[ -f "$local_conf" ]]; then
				printf '%s\n' "running local config: $local_conf" >&2
				# shellcheck disable=SC1090
				. "$local_conf"
			else
				:
			fi
			### use match to include a distro name based configuration
			match_conf="${MATCHES_DIR}/${match}.conf"
			if [[ -f "$match_conf" ]]; then
				printf '%s\n' "running match config: $match_conf" >&2
				# shellcheck disable=SC1090
				. "$match_conf"
			else
				:
			fi
			### try to modify architecture for 32-bit OSs
			if [[ $filename =~ *i386* || $filename =~ *32bit* ]]; then
				vm_ostype="${vm_ostype%_64}"
				vm_firmware="bios"
			fi
			### if not set explicitly compute VMs cpu count from host
			vm_cpu_count=$(_init_vm_cpu_count)
			### if not set explicitly compute VMs memory size from host
			vm_memory_size=$(_init_vm_memory_size)
			### evaluate command line options
			for key in ${!command_line_configs[*]}; do
				printf "using: ${key}='${command_line_configs[$key]}'\n" >&2
				eval ${key}="${command_line_configs[$key]}"
			done
			### let the show begin...
			_notify "Creating new VM" "\"$vm_name\"..."
			vmms::create_vm "$vm_name" && _created=0
			### create desktop entry for starts from start menu
			if (( $_created == 0 )); then
# 				if $create_desktop_menu_entry; then
				$dry || _create_desktop_entry "$vm_name"
# 			fi
			fi
			### desktop 'notification' on success and eventualy power the box up
			if ! $pwr; then
				if _yes_no "New VM added: '$vm_name', power up now?" 'Power Up' 'Not Yet'; then
					pwr=true
				fi
			fi
			if $pwr; then
				### run vbox, run
				vmms::start_vm "$vm_name"
			else
			# 	notify-send --app-name="${MY_TITLE}" --icon=virtualbox --expire-time=$notification_timeout "New VM not started"
				_notify "New VM not started"
			fi
			_exit=$_created
			_return=$_created
		;;
		delete | remove )
			### to delete an existing vm an exact(!) name is required
			# TODO implement --dry (here or in the functions script?)
			_deleted=1
			_vm="${_argv[1]}"
			vmms::vm_exists "${_vm}" || _error_exit "this VM does not exist: ${_vm} ($LINENO)" # --quiet?
			vmms::vm_is_stopped "${_vm}" || _error_exit "can not delete a running VM: ${_vm} ($LINENO)" # --quiet?
			_warning "Delete VM: '${_vm}'" && vmms::delete_vm "${_vm}" && _deleted=0
			### delete desktop entry for starts from start menu
			if (( $_deleted == 0 )); then
				$dry || _delete_desktop_entry "$_vm"
			fi
			_exit=$_deleted
			_return=$_deleted
		;;
		delete-desktop-entry | remove-desktop-entry )
			_deleted=1
			# TODO exit if argument is not given (is this handled elsewehere? i guess not!
			$dry || _delete_desktop_entry "${_argv[1]}" && _deleted=0
			_exit=$_deleted
			_return=$_deleted
		;;
		export ) # WARNING NOT TESTED AT ALL. THIS IS JUST A FIRST DRAFT
			_exported=1
			### if filepath not set via option -f, use first argument instead
			if [[ -z "$filepath" ]]; then
				if [[ -n "${_argv[1]}" ]]; then
					filepath="${_argv[1]}.ova"
					_verbose "filepath=$filepath (by \$1)"
					shift 1
				fi
			fi
			### still no file path? > fail
			if [[ -z "$filepath" ]]; then
				_error_exit "No Appliance image file path given. Giving up. ($LINENO)"
			fi
			_vm="${_argv[1]}"
			vmms::vm_exists "${_argv[1]}" || _error_exit "this VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
			vmms::vm_is_stopped "${_argv[1]}" || _error_exit "can not export a running VM: ${_argv[1]} ($LINENO)" # --quiet?

			# TDOO: check if file exists, ask to overwrite (e.e. delete now) or cancel

			vmms::export_vm "${_vm}" "$filepath" && _exported=0
			_exit=$_exported
			_return=$_exported
		;;
		import )
			_imported=1
			### if filepath not set via option -f, use first argument instead
			if [[ -z "$filepath" ]]; then
				if [[ -n "${_argv[1]}" ]]; then
					filepath="${_argv[1]}"
					_verbose "filepath=$filepath (by \$1)"
					shift 1
				fi
			fi
			### still no file path? > fail
			if [[ -z "$filepath" ]]; then
				_error_exit "No Appliance image file path given. Giving up. ($LINENO)"
			fi
			### use filename as in filepath to suggest a vm name
			filename=${filepath##*/}
			_verbose filename=$filename
			### inform the user*in"
			if [[ $yes = true ]]; then
				:
			else
				if ! _yes_no "Import Appliance from \"$filename\"?" "Import" "Cancel"; then
					_canceled_exit
				fi
			fi
			### create a simple suggestion for the vm name from ISO image file name
			vm_name_suggest="${filename%.*}"
			vm_name_suggest="${vm_name:-$vm_name_suggest}"
			_verbose "STAMP=$STAMP" >&2
			if $create_stamp; then
				if [[ -n "$STAMP" ]]; then
					vm_name_suggest="${vm_name_suggest} (${STAMP})"
				else
					vm_name_suggest="${vm_name_suggest} (${TODAY})"
				fi
			fi
			_verbose "vm_name_suggest=$vm_name_suggest" >&2
			### get a name for the new virtual machine
			if [[ $yes = true ]]; then
				vm_name="$vm_name_suggest"
			else
				# unfortunately kdialog --imginputbox does not respect additional preset text as --inputbox does,
				# so we can not use a nice icon here: "$BIN_DIR/${MY_NAME}.d/icons.d/display-and-tower.svg"
				# extra spaces trainling the proposed text are required as kdialog does not respect the text length
				if ! vm_name=$(_get_vm_name "$vm_name_suggest"); then
					_canceled_exit
				fi
			fi
			### let the show begin...
			_notify "Importing Appliance as VM" "\"$vm_name\"..."
			vmms::import_applicance "$filepath" "$vm_name" && _imported=0
			### create desktop entry for starts from start menu
			if (( $_imported == 0 )); then
				_create_desktop_entry "$vm_name"
			fi
			### desktop 'notification' on success and eventualy power the box up
			if ! $pwr; then
				if _yes_no "New VM added: '$vm_name'. Power up now?" "Power Up" "Not Yet"; then
					pwr=true
				fi
			fi
			if $pwr; then
				### run vbox, run
				vmms::start_vm "$vm_name"
			else
			# 	notify-send --app-name="${MY_TITLE}" --icon=virtualbox --expire-time=$notification_timeout "New VM not started"
				_notify "New VM not started"
			fi
			_exit=$_imported
			_return=$_imported
		;;
		info )

			_vm="${_argv[1]}"
			vmms::vm_exists "${_vm}" || _error_exit "this VM does not exist: ${_vm} ($LINENO)" # --quiet?
			vmms::vm_info "${_vm}"
			_exit=0
			_return=0
		;;
		help )
			_usage >&2
			_exit=0
			_return=0
		;;
		list )
			if $list_running; then
				vmms::list_vms_running
			elif $list_stopped; then
				vmms::list_vms_stopped
			else
				vmms::list_vms
			fi
			_exit=0
			_return=0
		;;
		open )
			_opened=1
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "this VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_stopped "${_argv[1]}" || _error_exit "can not start a running VM: ${_argv[1]} ($LINENO)"
# 			vmms::open_vm "${_argv[1]}" && _opened=0
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			vmms::vm_is_stopped "${_vm}" || _error_exit "can not start a running VM: ${_vm} ($LINENO)"
			vmms::open_vm "${_vm}" && _opened=0
			_exit=$_opened
			_return=$_opened
		;;
		readdocs )
# 			xdg-open "$MY_GIT_HOME" # this should work, but it doesn't
			kioclient exec "$MY_GIT_HOME" 2>/dev/null
			_exit=0
			_return=0
		;;
		rename | move ) # move is not propagated synonym for rename but might be used in future implementations to "physically" move a VM to a different storage location
			_renamed=1
			_vm_old_name="${_argv[1]}"
			_vm_new_name="${_argv[2]}"
			[[ -n $_vm_old_name ]] || _error_exit "no existing vm name given ($LINENO)"
			[[ -n $_vm_new_name ]] || _error_exit "no new vm name given ($LINENO)"
			[[ $_vm_old_name == $_vm_new_name ]] || _error_exit "new vm name equals the old name ($LINENO)"
			vmms::vm_exists "${_vm_old_name}" || _error_exit "this VM does not exist: ${_vm_old_name} ($LINENO)" # --quiet?
			vmms::vm_is_stopped "${_vm_old_name}" || _error_exit "can not rename a running VM: ${_vm_old_name} ($LINENO)" # --quiet?
			vmms::rename_vm "${_vm_old_name}" "${_vm_new_name}" && _renamed=0
			### delete and create desktop entry for starts from start menu
			if (( $_renamed == 0 )); then
				_delete_desktop_entry "${_vm_old_name}"
				_create_desktop_entry "${_vm_new_name}"
			fi
			_exit=$_renamed
			_return=$_renamed
		;;
		search | query )
			_matched=1
			vmms::query_vm "${_argv[1]}" && _matched=0
			_exit=$_matched
			_return=$_matched
		;;
		search-desktop-entry )
			_matched=1
			$dry || _search_desktop_entry "${_argv[1]}" && _matched=0
			_exit=$_matched
			_return=$_matched
		;;
		snap )
			### NOTE the vbox snapshot command has a --live option to allow snapshots from running VMs, but we do not recommend to trust on this
			_snapped=1
			echo "searching ${_argv[1]} ..." >&2
			_vm="$(vmms::query_vm "${_argv[1]}" | head -1)"
			[[ -n "$_vm" ]] || _error_exit "there is no VM matching: '${_argv[1]}' ($LINENO)"
# 			vmms::vm_is_stopped "${_vm}" || _error_exit "can not snap a running VM: ${_vm} ($LINENO)"
			echo "snapping $_vm ..." >&2
			vmms::snap_vm "${_vm}" && _snapped=0
			_exit=$_snapped
			_return=$_snapped
		;;
		start | launch )
			_started=1
			# DONE behave like query/search
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "this VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_stopped "${_argv[1]}" || _error_exit "can not start a running VM: ${_argv[1]} ($LINENO)"
# 			vmms::start_vm "${_argv[1]}" && _started=0
			echo "searching ${_argv[1]} ..." >&2
# 			vmms::query_vm "${_argv[1]}"
#			vmms::query_vm "${_argv[1]}" | head -1
			_vm="$(vmms::query_vm "${_argv[1]}" | head -1)"
# 			echo "found $_vm" >&2
			[[ -n "$_vm" ]] || _error_exit "there is no VM matching: '${_argv[1]}' ($LINENO)"
			vmms::vm_is_stopped "${_vm}" || _error_exit "can not start a running VM: ${_vm} ($LINENO)"
			echo "starting $_vm ..." >&2
			vmms::start_vm "${_vm}" && _started=0
			_exit=$_started
			_return=$_started
		;;
		state | status )
# 			vmms::vm_exists "${_argv[1]}" && printf '%s\n' "vm exists"
# 			vmms::vm_is_running "${_argv[1]}" && printf '%s\n' "vm is running"
# 			vmms::vm_is_stopped "${_argv[1]}" && printf '%s\n' "vm is stopped"
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			vmms::vm_is_running "${_vm}" && printf '%s\n' "vm is running"
			vmms::vm_is_stopped "${_vm}" && printf '%s\n' "vm is stopped"
			_exit=0
			_return=0
		;;
		stop | pause )
			_stopped=1
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "this VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_running "${_argv[1]}" || _error_exit "can not stop a stopped VM: ${_argv[1]} ($LINENO)"
# 			vmms::stop_vm "${_argv[1]}" && _stopped=0
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			[[ -n _vm ]] || _error_exit "there is no VM matching: ${__argv[1]} ($LINENO)"
			vmms::vm_is_running "${_vm}" || _error_exit "can not stop a stopped VM: ${_vm} ($LINENO)"
			vmms::stop_vm "${_vm}" && _stopped=0
			_exit=$_stopped
			_return=$_stopped
		;;
		update ) # me from github?
			_exit=0
			_return=0
		;;
		view )
			_viewing=1
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "this VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_running "${_argv[1]}" || _error_exit "can not start a running VM: ${_argv[1]} ($LINENO)"
# 			vmms::view_vm "${_argv[1]}" && _viewing=0
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			[[ -n _vm ]] || _error_exit "there is no VM matching: ${__argv[1]} ($LINENO)"
			vmms::vm_is_running "${_vm}" || _error_exit "can not start a running VM: ${_vm} ($LINENO)"
			vmms::view_vm "${_vm}" && _viewing=0
			_exit=$_viewing
			_return=$_viewing
		;;
	esac
	# TODO return or exit? this is (called) function, so return
# 	printf '\n' >&2
# 	exit $_exit
	return $_return
}



### EVALUATE COMMMANDS BEFORE OPTIONS
### there is just one allowed and it must preceed all other
### command line parameters if any
for command in ${valid_commands[*]}; do
	if [[ $# -gt 0 ]]; then
		if [[ $command == $1 ]] ; then
# 			$command=true
# 			create=false
			COMMAND="$1"
			shift 1
			break
		fi
	fi
done

### get profile and file name from command line
tmpl=false

### dynamic config values via command line
declare -A command_line_configs
valid_options=$(getopt \
-o \
adE:f:ghI:i:n:o:P:prs:tuVvxy \
--long \
auto,\
auto-magic,\
debug,dry-run,\
export:,\
file:,\
from:,\
gui,\
help,human,\
import:,iso:,isofile:,\
libvirt,\
name:,\
option:,output:,\
power-up,profile:,\
qemu,\
running,\
stamp:,\
stopped,\
terminal,\
version,vbox,verbose,virsh,vmm:,\
yes \
-- "$@")

### did getopt parsed nicely?
if [[ $? -ne 0 ]]; then
	error_txt="$(gettext "has more information")"
	printf "'$MY_NAME --help' $error_txt\n" >&2
    exit 1
fi

### init the evaluation loop
eval set -- "$valid_options"

### evaluate remaining command line options (if any remains)
while [ : ]; do
	OPT="$1"
	OPTARG=''
	_debug OPT="$OPT" >&2
# 	[[ -v 2 ]] && OPTARG="$2" # not operational in bash versions lower than 5.1 as of 2020-12
# 	[ -v 2 ] && OPTARG="$2"
# 	test -v 2 && OPTARG="$2"
	# so we use an alternate more 'historic' approach
# 	[[ $# -ge 2 && $2 != \-\- ]] && OPTARG="$2" # i'm stuck on this
# 	if [[ $# -ge 2 && ! "$2" == '--' ]]; then
	if [[ $# -ge 2 && "$2" != '--' ]]; then
		OPTARG="$2"
		_debug OPTARG="$OPTARG" >&2
	fi
	case $OPT in
		-a | --auto-magic | --auto )
			_verbose "running in automagic mode ..." >&2
			auto=true
			_verbose "auto=$auto"
			shift
		;;
		-d | --dry-run )
			_verbose "running in dry mode ...\n" >&2
			# shellcheck disable=SC2034
			dry=true
			_verbose "dry=$dry"
			shift
		;;
		-g | --force-gui )
			_verbose "running in forced gui mode ..." >&2
			gui=true
			cli=false
			shift
		;;
		-h | --help )
			_usage >&2
			exit 0
		;;
		--human )
			human_readable=true
			shift
		;;
		-f | --file | --from | -i | --iso | --isofile )
			_verbose "f=$OPTARG" >&2
			filepath="$OPTARG"
			_verbose \$filepath=$filepath "[by -f]"
			shift 2
		;;
		-n | --name )
			_verbose "n=$OPTARG" >&2
			vm_name="$OPTARG"
			shift 2
		;;
		-o | --option )
			_verbose "o=$OPTARG" >&2
			### put this in a stack and execute later after reading confs and
			### profiles after a minimal check on validity
			if [[ "$OPTARG" =~ [a-z]=.? ]]; then
				option_key="${OPTARG%%=*}"
				option_value="${OPTARG#*=}"
				command_line_configs[$option_key]="$option_value"
				_verbose "${!command_line_configs[*]}" >&2
				_verbose "${command_line_configs[*]}" >&2
			else
				_verbose "option \"$OPTARG\" ignored because of invalid syntax. should be foo=\"bar\"" >&2
			fi
			shift 2
		;;
		--out | --output )
			_verbose "f=$OPTARG" >&2
			filepath="$OPTARG"
			_verbose \$filepath=$filepath "[by --output]"
			shift 2
		;;
		-p | --profile )
			_verbose "t=$OPTARG"
			profile="$OPTARG"
			declare -l tmpl_cand
			# check valid profile name by existence of profile file (allowed to be empty)
			for conf in "${PROFILES_DIR}"/?*.conf "${PROFILES_DIR_LOCAL}"/?*.conf; do
				tmpl_cand="${conf%.conf}"
				tmpl_cand="${tmpl_cand##*/}"
				if [[ "$tmpl_cand" =~ $profile ]]; then
					tmpl=true
					break
				fi
			done
			if ! $tmpl; then
				_warning "profile does not exists: '${profile}.conf'. Continue with fallback to Linux?" || _canceled_exit
				profile="linux"
				tmpl=true
			fi
			shift 2
		;;
		--libvirt )
			VMM=libvirt
			shift
		;;
		--virsh )
			VMM=libvirt
			shift
		;;
		--qemu )
			VMM=libvirt
			shift
		;;
		--running )
			list_running=true
			shift
		;;
		-s | --stamp )
			STAMP="$OPTARG"
			shift 2
		;;
		--stopped )
			list_stopped=true
			shift
		;;
		-t | --terminal )
			terminal=true
			shift
		;;
		-u | --power-up )
			# power up after creating
			# shellcheck disable=SC2034
			pwr=true
			_verbose "pwr=$pwr"
			shift
		;;
		--vbox )
			VMM=vbox
			shift
		;;
		-V | --version )
			printf '%s\n' "Version: $VERSION" >&2
			exit 0
		;;
		-v | --verbose )
			printf '%s\n'  "enabling verbose mode ..." >&2
			VERBOSE=true
			shift
		;;
		--vmm )
			VMM=$OPTARG
			shift 2
		;;
		-X )
			### legacy option
			gui=true
			cli=false
			shift
		;;
		-x | --debug )
			_verbose "enabling DEBUG mode ..." >&2
			DEBUG=true
			shift
		;;
		-y | --yes )
			_verbose "enabling unattended mode ..." >&2
			yes=true
			_verbose "y=$yes"
			shift
		;;
		### anything else is an usage error (but caught already above by getopts)
		\? )
			error_str="$(gettext "Error")"
			error_txt="$(gettext "Unknown option")"
			printf "$MY_NAME: $error_str: $OPTARG\n" >&2
			printf "$MY_NAME --help\n" >&2
			exit 1
		;;
		### stop option processing
		-- )
			shift
			break
		;;
    esac
done

### import vmm based interface set
if [[ -v VMM ]]; then
	if [[ -f "${VMMS_DIR}/${VMM}/functions.sh" ]]; then
		source "${VMMS_DIR}/${VMM}/functions.sh"
	else
		_error_exit "VMM import module not found in: '${VMMS_DIR}/${VMM}/' ($LINENO)" 99
	fi
# 	# TODO shall this move into handling of create command? reasonable!
# 	if [[ -f "${VMMS_DIR}/${VMM}/config.sh" ]]; then
# 		source "${VMMS_DIR}/${VMM}/config.sh"
# 	else
# 		_error_exit "VMM vm config filters not found in: '${VMMS_DIR}/${VMM}/' ($LINENO)" 99
# 	fi
else
	_error_exit "no VMM defined ($LINENO). Either use command line: --<vmm-name> or --vmm=<vmm-name> or environment VMMCTL_VMM=<vmm-name>. Currently there is only 'vbox' as a valid vmm-name." 99
fi

if [[ ! -v COMMAND ]]; then
# 	_error_exit "no COMMAND defined Use command line: $ME <command-name>. Valid command are: 'create', 'clone', 'start', 'stop', 'delete', 'remove', 'rename', 'import', 'info', 'list', 'pause'. ($LINENO)" 99
	printf '\n%s\n' "ERROR: $MY_NEW_NAME requires a COMMAND at minimum"
	printf '\n%s\n\n' "Use $MY_NEW_NAME -h for a list of commands and options"
	exit 99
fi

echo
echo "running internal command:" "$COMMAND" "$@" >&2

_run_command $COMMAND "$@" ; ret=$?
printf '\n' >&2

# wait on user if in terminal
$terminal && read -p 'type Enter to close this terminal ...'

# cleanup in case this is run by "sourcing" this file
set +u

# exit with commands return code
exit $ret

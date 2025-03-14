#!/usr/bin/env bash

# vim: syntax=sh tabstop=4 softtabstop=0 expandtab shiftwidth=4 smarttab :

# this script requires minimum version 4 as of Bash on the 20th of February, 2009

### https://www.ip-insider.de/was-ist-ein-vmm-virtual-machine-monitor-a-3dddd13fb17d2d776529f03465788118/
### > Virtual Machine Monitor ist eine alternative Bezeichnung für Hypervisor.

### vmm is technically correct, but not distinguishabel enough from virtual machine manager project

### other names:  hypercon or (short) vc ? (with --hyper= or --hv= options ? bad: -h)
### https://hypercon.eu  :(
### https://w140.com/tekwiki/wiki/Hypcon
### https://www.hvc-technologies.de/
### https://de.wikipedia.org/wiki/HVC

### author: hartmann.christian@gmail.com, c-hartmann@github.com, github.com/c-hartmann
### description: Creates a Virtual Machine from suitable ISO images or controls existing
### last update: 2024-09-01

### preferred places to live in:
### $HOME/.local/bin/
### $HOME/.local/share/kservices5/ServiceMenus/ (where the service menu wrapper goes)
### SPDX-FileCopyrightText: 2024 Christian Hartmann <hartmann.christian@gmail.com>
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

### ###########################################################################

### me, myself and i
MY_NAME="vmmctl" # still in use for gettext(1)
MY_NEW_NAME="vmmcon"

### how old i am?
VERSION="0.1.50"

### by default this is not verbose
VERBOSE=false

### deprecated base and fallback for vm name stamp
TODAY="$(date --iso-8601)"

### exit immediatly if a command exits with a non-zero status
### WARNING: uncommenting won't allow kdialogs getting canceled
# TODO: capsulate these processes with set +o or unset -o ?
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

### _usage
### dead simple usage help on command line use
function _usage()
{
	cat << ____USAGE
${MY_NEW_NAME}:${VERSION}
	
Usage: ${MY_NEW_NAME} <command> [options] [<iso-image-file> | <vm-name>]

Commands:

  launch <iso>                  Create _and_ start new VM

  create <iso>                  Create a new VM from ISO
  start <vm>                    Start an existing VM
  stop <vm>                     Stop a VM. (save state and close VM)
  reboot <vm>                   Restart a VM (see options --ssh --acpi)
  halt <vm>                     Shutdown a VM (gracefully) (--ssh --acpi)
  reset <vm>                    Discard any state and poweroff a VM

  snap <vm>                     Take a snapshot of the VM

  info <vm>                     Show infos of VM
  status <vm>                   Show status of VM

  rename <vm> <vm>              Rename a VM
  clone <vm> <vm>               Create a copy of an existing VM by its name
  delete <vm>                   Delete an existing VM by its exact name
  
  open --<prot> <vm>            Open a session with the vm. Prot is one of 'https' (default), 'http' or 'ssh'
  login <vm>                    Enter into the vm via ssh(1)
  exec <vm> <command>           Tries to execute a command either via ssh(1) or other mechanisms

  list                          List all VMs
  list <name>                   List VMs with names starting with <name>

  export <vm>                   Export an existing VM by its name as Appliance
  import <app> [<vm>]           Create a new VM from an application container  # TODO: use existing VM name / Auto (re)name?

  help                          Shows help (on command line)
  readdocs                      Open the documentation in default browser

Options on creation of a new VM:

  -a | --auto                   Determine the profile auto-magically
  -d | --dry-run                Dry run - do not create anything
  -i | --iso                    More explicit approach to set ISO image file name
  -n | --name                   Name the machine to create
  -o | --option                 Set option by it's name as in foo=bar
  -p | --profile <profile>      A profile to use
  -S | --stamp <stamp>          Append <stamp> instead of the default to vm name
  -u | --power-up               Power up the VM after creating one
  -y | --yes                    Assume yes to all interactive questions

if no image file is given but required, it will be requested interactively

  --vmm=<VMM>                   Use VMM as VMM
  --vbox                        Use VirtualBox as VMM
  --qemu                        Use QEMU/libvirt/VMM as VMM

generic options:

  -h | --help                   Show this help
  -g | --force-gui              Force GUI mode from terminal
  -v | --verbose                Turn on verbose mode
  -V | --version                Print the version and exit

____USAGE
}


### debugging might be enabled by exported environment variable (default to false)
DEBUG=${VMMCON_DEBUG:-false}; $DEBUG && set -x

# TODO does this make any sence still? since we gave SHARE_PATH now?
# >    diabling here now. delete later…
### my installation directoryKommt der Repeater dann eher in die Nähe des Routers oder dahin, wo ich empfangen will?
# BIN_DIR="$(dirname "$(readlink -m "$0")")"
# if [[ ! -d "${BIN_DIR}" ]]; then
# 	_error_exit "FATAL: not found BIN_DIR: ${BIN_DIR}. Giving up. ($LINENO)"
# else
# 	$VERBOSE && printf "running in ${BIN_DIR} [1]\n"
# fi

MY_RC="$HOME/.config/vmmconrc"
MY_PATH="${BASH_SOURCE[0]}"
MY_FILE="${MY_PATH##*/}"
MY_FILE="${MY_FILE%%.*}"
MY_SHARE_PATH="$HOME/.local/share/${MY_NEW_NAME}:$HOME/.${MY_NEW_NAME}:/usr/local/share:/usr/share"
MY_GIT_HOME='https://github.com/c-hartmann/vmmcon.sh'

### use first available in share path for MY_SHARE
### credit:
### to: https://stackoverflow.com/users/1815797/gniourf-gniourf
### in: https://stackoverflow.com/questions/11655770/looping-through-the-elements-of-a-path-variable-in-bash
IFS=: read -r -d '' -a path_array < <(printf '%s:\0' "$MY_SHARE_PATH")
for p in "${path_array[@]}"; do
    ### just use this, so we have a fallback path at least from last entry in path
    MY_SHARE="$p"
    [[ -d "$p" ]] && break
done

### desktop integration requires launchers build from these templates
# TODO switch to vmmcon inside these templates
VMMCON_DESKTOP_ENTRY_TEMPLATE="desktop-entry-template.desktop"
VMMCON_DESKTOP_MENU_TEMPLATE="desktop-menu-category.menu"
VMMCON_DESKTOP_DIRECTORY_TEMPLATE="desktop-menu-category.directory"

### desktop Launcher (at least on KDE) does not respect commands in PATH
### until you configure it to do so
### try creating or editing $HOME/.config/plasma-workspace/env/path.sh
### see: https://userbase.kde.org/Session_Environment_Variables
# currently hard coded
# VMMCON_PATH_CANONICAL="$(readlink -f "$MY_PATH")" # or just readlink -f $0 ?
# shellcheck disable=SC2034 # used in template
VMMCON_PATH_CANONICAL="$HOME/.local/bin/vmmcon" # might be a link to vmmcon.sh

# a usual shortcut
# TODO: replace instances of MY_NEW_NAME with ME here?
# shellcheck disable=SC2034 # used in functions
ME="${MY_NEW_NAME}"

# default title (for dialogs and such)
# MY_TITLE="Virtual Machine Monitor Console" # VM Monitor is a nick for Hypervisor
MY_TITLE="VMMCON" # VM Monitor is a nick for Hypervisor

# depending in my command name / binary create might be a default
if [[ "${MY_FILE}" =~ ^create-.* ]]; then
	### but default mode is true (long: createfromiso)
	# shellcheck disable=SC2034 # used in functions
	createfromiso=true
	### create is currently just a short cut to createfromiso (about to change)
	# shellcheck disable=SC2034 # used in functions
	create=true
	### new command mode
	COMMAND='create'
fi

### l10n
export TEXTDOMAIN="${MY_NAME}"
export TEXTDOMAINDIR="${MY_SHARE}/locale"
### execute the builtin script
# shellcheck disable=SC1091
. gettext.sh

### this is based on the idea of vm profiles and this is where they live
PROFILES_DIR="${MY_SHARE}/profiles"
# PROFILES_DIR_LOCAL="${MY_SHARE}/profiles.local"

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
iso_download_top_dir=""

### initialize dialog type
declare gui
declare cli
declare tui
if [[ ! -t 0 ]]; then
	# running via service menu
	gui=true
	cli=false
	tui=false
else
	# running from command line
	gui=false
	cli=false
	tui=true # either whiptail or dialog
fi

### we are started from context menu but run in terminal
terminal=false

### set some defaults so we do not fail on using these later
STAMP="-$(date --iso-8601)"

### every new VM name will be trailed by a STAMP based on current date
create_stamp=$(true)
# create_stamp=true # ?

### every new VM will be added to start menu system
create_desktop_menu_entry=$(true)
# create_desktop_menu_entry=true # ?
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
desktop=false
# select=false

vmmcon_defaults_editor="${EDITOR:-vim}" # used?
vmmcon_defaults_editor_run_in_terminal=false # used?

### VMM selector switch
# vbox=true
# qemu=false
# libvirt=false
# vmware=false

### no default VM to operate on
# VM=''

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
# shellcheck disable=SC2034 # used in functions
vm_vram_size=128

### disk size (in GB)
# shellcheck disable=SC2034 # used in functions
vm_disk_size=40
# shellcheck disable=SC2034 # used in functions
vm_disk_count=1
# shellcheck disable=SC2034 # used in functions
vm_disk_type="vdi" # other: vdi (default), vhd (M$?), vmdk (smart altenative as readable also by qemu)
# shellcheck disable=SC2034 # used in functions
vm_disk_alloc="dynamic"

### Enable PAE/NX: Determines whether the PAE and NX capabilities of the host CPU will be exposed to the virtual machine
### (64 Bit system do make any use of it)
# shellcheck disable=SC2034
# shellcheck disable=SC2034 # used in functions
vm_pae="off"

### motherboard
### Be sure to enable I/O APIC for virtual machines that you intend to use in 64-bit mode. (https://www.virtualbox.org/manual/ch03.html)
# shellcheck disable=SC2034 # used in functions
vm_ioapic="on"       # (TODO: rename to vbox_* scheme) ???
# shellcheck disable=SC2034
# shellcheck disable=SC2034 # used in functions
vm_chipset="piix3"
# shellcheck disable=SC2034
# shellcheck disable=SC2034 # used in functions
vm_firmware="bios" # bios|efi|efi32|efi64
# shellcheck disable=SC2034
# shellcheck disable=SC2034 # used in functions
vm_acpi="on"
### clock (defaults to no utc clock)
# shellcheck disable=SC2034 # used in functions
vm_rtcuseutc="on"

### cpu
# see: https://www.it-swarm.com.de/de/virtualbox/wann-muss-ich-pae-nx-verwenden/944835828/
### there is no use of PAE for 64 bit guests
### in gereral you do not want to passthrough of hardware virtualization functions to the guest VM
# shellcheck disable=SC2034 # used in functions
vm_pae="off"          # (TODO: rename to vbox_* scheme)
# shellcheck disable=SC2034 # used in functions
vm_nested_virt="off"  # (TODO: rename to vbox_* scheme)

### support neted paging on vt enabled hosts only
# shellcheck disable=SC2034 # used in functions
vm_nestedpaging="off" # (TODO: rename to vbox_* scheme)
# vm_hypervisor="default" # DEPRICATED
# shellcheck disable=SC2034 # used in functions
vbox_vm_paravirtprovider="none"

### VBox recommends to use VMSVGA graphics controller for Linux guests, so we do.
### VMSVGA: Use this graphics controller to emulate a VMware SVGA graphics device.
### This is the *default* graphics controller for Linux guests.
### unfortunately this comes with the essential limitation of 800x600 screen size
# shellcheck disable=SC2034 # used in functions
vm_gfx_controller="vmsvga" # default: "vmsvga", other: vboxvga, vboxsvga

### EFI screen resolutions (https://www.virtualbox.org/manual/ch03.html#efi)
### vm_efi_gfx_resolution="1920x1200" # WUXGA
### vm_efi_gfx_resolution="1280x1024" # SXGA
### more here: https://docs.oracle.com/en/virtualization/virtualbox/6.0/user/efi.html
# shellcheck disable=SC2034 # used in functions
vm_efi_gfx_resolution="1280x800"  # WXGA

### most newer linux make use of 3D accelaration feature if present
### so we do (via $ME.conf although it defaults to off and requires
### guest additions being installed
# shellcheck disable=SC2034 # used in functions
vm_gfx_accelerate3d="off"

### these are the defaults for Linux guests
# "ps2kbd" for keyboard?
# see: vboxmanage showvminfo --machinereadable $VM | grep -E 'hidkeyboard|hidpointing'
# shellcheck disable=SC2034 # used in functions
vm_hid_pointing="usbtablet"
# shellcheck disable=SC2034 # used in functions
vm_hid_keyboard="ps2"

### level of USB support at host
# shellcheck disable=SC2034 # used in functions
vm_usb="on"      # USB-1.1, default: "off"
# shellcheck disable=SC2034 # used in functions
vm_usb_ehci="off" # USB-2.0, default: "off" # incompatible vbox ext pack can prevent system
# shellcheck disable=SC2034 # used in functions
vm_usb_xhci="off" # USB-3.0, default: "off" # from booting if usb 2 or 3 support is enabled

### audio
# shellcheck disable=SC2034 # used in functions
vm_audioout="on"
# shellcheck disable=SC2034 # used in functions
vm_audioin="off"
# shellcheck disable=SC2034 # used in functions
vm_audiocontroller="ac97"
# shellcheck disable=SC2034 # used in functions
vm_audiocodec="ad1980" # default in gui mode

### network
vm_network_mode="nat" # or "bridged", "hostonly", "...",


### vbox allows custom graphics resolutions
# shellcheck disable=SC2034 # used in functions
declare -a vm_gfx_controller_resolutions

open_protocol=''

### execute the config file now as this might impact the calculation of cpu core
# CONF="${MY_DIST}/${MY_NAME}.conf"
# if [[ -f "$CONF" ]]; then
# 	# shellcheck disable=SC1090
# 	. "$CONF"
# fi
# RC="${MY_SHARE}/${ME}rc"
if [[ -f "$MY_RC" ]]; then
	# shellcheck disable=SC1090
	. "$MY_RC"
fi


# TODO: we might do things other way around: run rc first and
#       use parameter expansion syntax after. e.g.:
#       vm_audioout="${vm_audioout:-"on"}




# NOTE: neither env::VMMCTL_VMM, nor config::vmm shall override VMM setting via file name
#       but VMMCTL_VMM shall override config::vmm
if [[ ! -v VMM ]]; then
	VMM="${VMMCTL_VMM:-$vmm}"
fi




### _json_read_jq file object path
function _json_read_jq()
{
	local json_file
	local jq_path
	json_file="$1"; shift
	jq_path="$(printf '.%s' "$@")"
	jq -r "${jq_path}" < "$json_file"
}

### _json_read_p(ython)3 file object path
function _json_read_p3()
{
	local json_file
	local p3_path
	json_file="$1"; shift
	p3_path="$(printf '["%s"]' "$@")"
	python3 -c "import sys, json; print(json.load(sys.stdin)${p3_path})" < "$json_file"
}

### _json_read file object path
function _json_read()
{
	if [[ $jq ]]; then
		_json_read_jq "$@"
	elif [[ $p3 ]]; then
		_json_read_p3 "$@"
	else
		echo 'ERROR'
		exit 99
	fi
}

### _strip # string
function _strip()
{
	local _string="$1"
	_string="${_string## }"
	_string="${_string%% }"
	printf '%s' "${_string}"
}

### _notify
### wrapper that respects gui or cli mode
function _notify()
{
	$gui && notify-send --app-name="${MY_TITLE}" --icon=virtualbox --expire-time=$notification_timeout "$@"
	$cli && printf "\n%s\n" "$@" >&2
}

### _error_exit
### even more simple error handling
function _error_exit()
{
	local error_str
	error_str="$(gettext "ERROR")"
	$gui && kdialog --title "${MY_TITLE}" --error "$error_str: $*" --ok-label 'So Sad'
	$cli && printf "\n%s: %s\n\n" "$error_str" "$1" >&2
	# shellcheck disable=SC2086 # shall be an integer - no sring quoting
	exit ${2:-1}
}

### _plain_exit
### even more simple error handling
function _plain_exit()
{
	$gui && kdialog --title "${MY_TITLE}" --msgbox "$*" --ok-label 'OK'
	$cli && printf "\n%s: %s\n\n" "$1" >&2
	# shellcheck disable=SC2086 # shall be an integer - no sring quoting
	exit ${2:-1}
}

### _canceled_exit
function _canceled_exit()
{
	_notify "canceled"
	exit 1
}

### _warning
function _warning()
{
	if $gui; then
		kdialog --title "${MY_TITLE}" --warningcontinuecancel "WARNING: $*"
		return $?
	else
		printf "\n" >&2
		read -r -p "WARNING: ${*}. Continue? [N/y] "
		REPLY="$(_strip "$REPLY")"
		[[ $REPLY =~ yY ]] && return 0
		[[ -z $REPLY ]] && return 1
		return 0
	fi
}

### _debug - print debug messages if in DEBUG mode
function _debug()
{
	$DEBUG && printf "%s\n" "$@" >&2
}

### _debug - print debug messages if in DEBUG mode
function _verbose()
{
	$VERBOSE && printf "%s\n" "$@" >&2
}

### _get_config <config name>
### return <config value>
function _get_config()
{
	local _cn="$1"
	eval printf '%s' "\$$_cn"
}

### _user_file_path - ask userin for path to image file
function _user_file_path()
{
	local _dir="$1"
	local _fp
	local _fn
	local _secs=10
	if $gui; then
		_fp=$(kdialog --title "${MY_TITLE}" --getopenfilename "$_dir" "application/x-cd-image application/vnd.efi.iso application/vnd.efi.img" 2>/dev/null)
		printf '%s' "$_fp"
	else
		# TODO replace 'which' by either 'type' or 'command'
		if which mimetype >/dev/null ; then
			printf 'looking for ISO images by mime type. this will take some time …\n' >&2
			printf '\n' >&2
			# shellcheck disable=SC2156
			( cd "$_dir" || _error_exit "can not change to directory"; find . -type f -exec bash -c "mimetype \"{}\" | grep -qe application/x-cd-image|application/vnd.efi.iso|application/vnd.efi.img" \; -print | sed 's#^./##' | sort >&2 )
		else
			( cd "$_dir" || _error_exit "can not change to directory"; find . -- *.iso *.ISO | grep -e '.iso$' | sed 's#^./##' | sort >&2 )
		fi
		printf "\n" >&2
		read -r -t $_secs -p "Enter one of the filenames above (within $_secs seconds): "
		REPLY="$(_strip "$REPLY")"
		_verbose "YOUR REPLY: '${REPLY:-none}'" >&2
 		[[ -z "$REPLY" ]] && return 1
 		_fn="$REPLY"
		printf '%s/%s' "$_dir" "$_fn"
	fi
}

### _auto_profile - get profile to use from local and global match profile table
function _auto_profile()
{
	local filename="$1"
	local matchtbl="$2"
	local temp
	local match
	local profile
	temp="$(mktemp)"
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
	# shellcheck disable=SC2002
	cat "$matchtbl" | sed 's/#.*//' | sed '/^[[:space:]]*$/d' > "$temp"
	# shellcheck disable=SC2034 # rest is used to catch extra args
	while IFS=$ifs read -r match profile rest; do
		if [[ "$filename" =~ .*$match.* ]]; then
			_verbose "MATCHED BY: $match" >&2
			_verbose "PROFILE IS: $profile" >&2
			break
		fi
	done < "$temp"
	set -o noclobber
	shopt -u nocasematch
	unset rest
	rm "$temp"
	printf '%s %s' "$match" "$profile"
}

function _is_in_profile_select_list()
{
	local tag="$1"
	local i
	for i in "${!profile_select_list[@]}"; do
		[[ "${profile_select_list[$i]}" == "$tag" ]] && return 0
	done
	return 1
}

function _get_array_index_from_value()
{
	local -n _array="$1"
	local    _value="$2"
	for i in "${!_array[@]}"; do
		if [[ ${_array[i]} == "$_value" ]]; then
			printf '%s' "$i"
			return
		fi
	done
	printf '%s' "-1"
}

### _user_profile - ask userin on profile to base vm on
function _user_profile()
{
	### build up a list of available profiles
	# https://linuxconfig.org/how-to-use-arrays-in-bash-script
	# https://stackoverflow.com/questions/29161323/how-to-keep-associative-array-order
# 	declare -A profile_select_list
	declare -a profile_select_list
#	# start with AUTO
# 	profile_select_list[auto]="AUTO"
	declare -a profile_select_list_helper
	local i
	i=1 ### NOTE the helper array will start with index 1
# 	for conf in "${PROFILES_DIR_LOCAL}"/*.conf "${PROFILES_DIR}"/*.conf; do
	for profile_conf in "${PROFILES_DIR}"/?*.conf; do
		name="UNKNOWN"
		# get simple tag from path to config file
		tag="${profile_conf%.conf}"
		tag="${tag##*/}"
# 		tag="${tag#*_}" # remove leading 'NN_'   # TODO there should a better solution .. e.g. profile=linux internally or tag=
		### add to Array if not already in (e.g. from local file)
# 		if [[ ! -v profile_select_list[$tag] ]]; then
		if ! _is_in_profile_select_list "$tag"; then
# 			profile_select_list[$i]="$tag" # TODO: $name ?
			# shellcheck disable=SC1090
			. "$profile_conf"
			profile_select_list[$i]="$name"
			profile_select_list_helper[$i]="$tag"
			((i++))
		fi
# 		profile_select_list[$i]="$tag"
# 		profile_select_list_helper[$i]="$tag"
#  		((i++))
	done
	### user selects…
	if $gui; then
		kdialog_radiolist_tag_item_list=" "
# 		kdialog_radiolist_tag_item_list+="auto auto on " # on triggers default selection
		for i in ${!profile_select_list[*]}; do
			### WARNING NEXT LINE WILL FAIL, IF $name HAS SPACES IN IT
			kdialog_radiolist_tag_item_list+="${profile_select_list[$i]} ${profile_select_list[$i]} off "
		done
		# shellcheck disable=SC2086 # the list shall be individual items - not just one option
		REPLY="$(kdialog --title "${MY_TITLE}" --radiolist "Select profile to use:" $kdialog_radiolist_tag_item_list)"
		### handle AUTO…
# 		if [[ $REPLY =~ auto ]]; then
# 			_verbose "choosing profile auto magically …" >&2
# 			# try local match table first
# 			if [[ -f "$automagic_table_local" ]]; then
# 				read match profile < <(_auto_profile "$filename" "$automagic_table_local")
# 			fi
# 			# no luck with local table? try global
# 			if [[ -z "$profile" ]]; then
# 				read match profile < <(_auto_profile "$filename" "$automagic_table")
# 			fi
# 			_verbose "choosen profile: $profile" >&2
# 			printf '%s' "$profile" # return to sender
# 		else
# 			profile="$REPLY"
# 			printf '%s' "$profile" # return to sender
			name="$REPLY"
			# get index from select list and return profile name from helper list
			index=$(_get_array_index_from_value 'profile_select_list' "$name")
			profile="${profile_select_list_helper[$index]}"
			printf '%s' "$profile"
# 		fi
	else # (cli)
# 		declare -u opt
		printf '\n' >&2
		printf 'Select profile …\n' >&2
		printf 'A) AUTO (default)\n' >&2
		i=1
# 		for i in ${!profile_select_list_helper[*]}; do
# 			tag="${profile_select_list_helper[$i]}" # TODO: name= ?
# 			printf "$i) ${profile_select_list[$i]}\n" >&2 # no more associative array
# 			((i++))
# 		done
		min=1
		for i in "${!profile_select_list[@]}"; do
			printf '%s) %s\n' "$i" "${profile_select_list[$i]}" >&2 # no more associative array
		done
		max=$i
		printf 'C) Cancel and exit\n' >&2
		printf 'Select profile (A)utomagically, by number 1 to %s or [C]ancel\n' "$max" >&2
		read -r -t 10 -p "» " 
		REPLY="$(_strip "$REPLY")"
		[[ -z "$REPLY" ]] && REPLY='A' # just assume Automatically on empty REPLY
		[[ $REPLY =~ [Cc] ]] && return 1
		### valid cancel options are none, x, X
		valid_reply_pattern="[AaCc0-9]+"
		[[ $REPLY =~ $valid_reply_pattern ]] || printf 'Selection invalid: %s\n' "$REPLY" >&2
		[[ $REPLY =~ $valid_reply_pattern ]] || return 1
		### get it automagically?
		if [[ $REPLY =~ [Aa] ]]; then
			_verbose "choosing profile auto magically …" >&2
			# try local match table first
			if [[ -f "$automagic_table_local" ]]; then
				read -r match profile < <(_auto_profile "$filename" "$automagic_table_local")
			fi
			# no luck with local table? try global
			if [[ -z "$profile" ]]; then
				read -r match profile < <(_auto_profile "$filename" "$automagic_table")
			fi
			_verbose "choosen profile: $profile" >&2
			printf '%s' "$profile" # return to sender
		else
			### REPLY shall not be less than 1
# 			[[ $REPLY -lt $min ]] && printf 'Selection out of range (min): %s\n' "$REPLY" >&2
# 			[[ $REPLY -lt $min ]] && return
			### REPLY shall not be greater than last index
# 			[[ $REPLY -gt $max ]] && printf 'Selection out of range (max): %s\n' "$REPLY" >&2
# 			[[ $REPLY -gt $max ]] && return
			# different approach...
			if (( "$REPLY" < $min || "$REPLY" > $max )); then
				printf 'Selection out of range (%s-$s): %s\n' "$min" "$max" "$REPLY" >&2
				return
			fi
			### any not existing hash in array will trigger cancel in caller
			# NOTE: next five lines disabled as non functional!
# 			opt=$REPLY
# 			p=${profile_select_list_helper[$opt]}
# 			printf "choosen: '${profile_select_list[$p]}'\n" >&2
# 			_verbose profile_select_list_helper[$opt]=${profile_select_list_helper[$opt]} >&2
# 			printf '%s' "${profile_select_list_helper[$opt]}" # return to sender
# 			printf '%s' "${profile_select_list_helper[$REPLY]}" # return to sender
			index=$REPLY
			profile="${profile_select_list_helper[$index]}"
			printf '%s' "$profile"
		fi
	fi
}

### _get_host_memory_size - get memory size of physical (aka host) system
function _get_host_memory_size()
{
	local _host_memory_size_kilobytes
	_host_memory_size_kilobytes=$(grep MemTotal < /proc/meminfo | grep -o '[[:digit:]]*') # or: awk '{print $2}'
	printf '%s' "$(( _host_memory_size_kilobytes / 1024 ))"
}

### _ask_vm_name - wrapper that asks userin for vm's name
function _ask_vm_name()
{
	local __vm_name_suggest="$1"
	local _vm_name
	local _spacer="                                          " # create a wider dialog
	if $gui; then
		_vm_name=$(kdialog --title "${MY_TITLE}" --icon=question --inputbox  "Name of virtual machine to create:$_spacer" "$__vm_name_suggest")
	else
		printf '\n' >&2
		printf 'Name the new virtual machine:\n' >&2
		read -r -t 10 -p "» " -e -i "$__vm_name_suggest"
		REPLY="$(_strip "$REPLY")"
		if [[ -z "${REPLY}" ]]; then
			_vm_name="$__vm_name_suggest"
		else
			_vm_name="${REPLY}"
		fi
		printf '\n' >&2
	fi
	printf '%s' "${_vm_name}"
}

### _create_and_ask_vm_name - wrapper that asks userin to create vm and for vm's name
function _create_and_ask_vm_name()
{
	local __iso_image_filename="$1"
	local __vm_name_suggest="$2"
	local _vm_name
	local _spacer="                                          " # create a wider dialog
	if $gui; then
		# no other than default label allowed here (--ok-label "Create")
		_vm_name=$(kdialog --title "${MY_TITLE}" --icon=question --inputbox "Create virtual machine with this name from '${__iso_image_filename}'?" "$__vm_name_suggest")
	else
		printf "\n" >&2
		printf "Create virtual machine with this name from '${__iso_image_filename}'?\n" >&2
		read -r -t 10 -p "» " -e -i "$__vm_name_suggest"
		REPLY="$(_strip "$REPLY")"
		if [[ -z "${REPLY}" ]]; then
			_vm_name="$__vm_name_suggest"
		else
			_vm_name="${REPLY}"
		fi
		printf "\n" >&2
	fi
	printf "%s" "${_vm_name}"
}

### _ask_yes_no - wrapper that respects gui or cli mode
function _ask_yes_no()
{
	_prompt="$1"
	_yes_label="$2"
	_no_label="$3"
	if $gui; then
		# shellcheck disable=SC2046 # shellcheck advices to quote, but return value is an integer
		return $(kdialog --title "${MY_TITLE}" --icon=question --yesno "${_prompt}" --yes-label "$_yes_label" --no-label "$_no_label")
	else
		printf '\n' >&2
		printf '%s\n' "$_prompt"
		read -r -t 10 -p "» [Y/n]"
		REPLY="$(_strip "$REPLY")"
		[[ $REPLY =~ ^$ ]] && return 0
		[[ $REPLY =~ [yY] ]] && return 0
 		return 1
	fi
}

### _ask_no_yes - wrapper that respects gui or cli mode
function _ask_no_yes() # TODO how set a default answer in kdialog?
{
	_prompt="$1"
	_yes_label="$2"
	_no_label="$3"
	if $gui; then
		# shellcheck disable=SC2046 # shellcheck advices to quote, but return value is an integer
		return $(kdialog --title "${MY_TITLE}" --icon=question --yesno "${_prompt}" --yes-label "$_yes_label" --no-label "$_no_label")
	else
		printf "\n" >&2
		read -r -t 10 -p "$_prompt [y/N] "
		REPLY="$(_strip "$REPLY")"
		[[ $REPLY =~ ^$ ]] && return 1
		[[ $REPLY =~ [yY] ]] && return 0
 		return 0
	fi
}

function _init_vm_cpu_count()
{
	local _host_cpu_count
	local _vm_cpu_count
	### things to determine by parent host (a third of actual cpu cores is
	### acceptabel and our default on computation)
	### grepping on processor would return physical/real cores, vmx also counts virtual cores
	_host_cpu_count="$(grep -Ec '(vmx|svm)' /proc/cpuinfo)" # if no output, host either so not support virtualization or it isn't enabled. bummer
	printf 'Host cpu count: %s\n' "$_host_cpu_count" >&2
	### 0 enables dynamic count
	if (( vm_cpu_count == 0 )); then
		printf '%s' "Computing count of virtual cpus …" >&2
		if (( _host_cpu_count > 0 )); then
		# TODO: use UPPER case names (and export?) to indicate external use? (in functions.sh)
			# shellcheck disable=SC2034 # used in functions.sh
			vm_nestedpaging="on" # defaults to on (i.e. using host cpu vt technology)
			# shellcheck disable=SC2034 # used in functions.sh
			vm_paravirtprovider="kvm" # kvm is default for Linux guests
			### compute a reasonable count for the count of guest cpu cores
			_vm_cpu_count=$(( _host_cpu_count / vm_cpu_count_divider ))
		else
			_vm_cpu_count=1
		fi
		printf "\b\b\b to: %s\n" "$_vm_cpu_count" >&2
	else
		printf 'Using fixed count of virtual cpus: %s\n' "$vm_cpu_count" >&2
		_vm_cpu_count=$vm_cpu_count
	fi
	printf '%u' $_vm_cpu_count
}

function _init_vm_memory_size()
{
	local _host_memory_size
	local _vm_memory_size
	_host_memory_size=$(_get_host_memory_size)
	if (( vm_memory_size == 0 )); then
		printf "Computing amount of virtual memory …" >&2
		if (( _host_memory_size > 0 )); then
			_vm_memory_size=$(( _host_memory_size / vm_memory_size_divider ))
		else
			_vm_memory_size=$vm_memory_size_fallback
		fi
		printf '\b\b\b to: %s\n' "$_vm_memory_size" >&2
	else

	printf 'Using fixed amount of virtual memory: %s\n' "$vm_memory_size" >&2
		_vm_memory_size=$vm_memory_size
	fi
	printf '%u' $_vm_memory_size
}

# --------------------------------------
# create a simple name from a complex one to utilize in filenames
function _get_simple_name()
{
	### TODO: check result (on being niot empty) before returning?
	# replace some characters with underscores, strip every '(' and ')'
	# TODO: doable with Bash string operations?
	local _complex_name="$1"
	printf '%s' "$_complex_name" | sed 's/[ !$/\]/_/g' | sed 's/[()]//g'
}

# --------------------------------------
# ensure we have a valid 'directory-file' (i.e. submenu) inside the menu structure
function _init_directory_entry()
{
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"
	local _xdg_menus_directory="$HOME/.config/menus/applications-merged"
	local _xdg_directories_directory="$HOME/.local/share/desktop-directories"
	local _xdg_desktop_menu_command
	_xdg_desktop_menu_command="$(type -p xdg-desktop-menu)" # TODO: use this varibale naming convention throughout the script
	_source="${MY_SHARE}/templates/xdg/${VMMCON_DESKTOP_MENU_TEMPLATE}"
	_target="${_xdg_menus_directory}/${_my_vendor_prefix}.${VMMCON_DESKTOP_MENU_TEMPLATE}"
	if [[ ! -f "${_target}" ]]; then
		cat "${_source}" > "${_target}"
	fi
	_source="${MY_SHARE}/templates/xdg/${VMMCON_DESKTOP_DIRECTORY_TEMPLATE}"
	_target="${_xdg_directories_directory}/${_my_vendor_prefix}.${VMMCON_DESKTOP_DIRECTORY_TEMPLATE}"
	if [[ ! -f "${_target}" ]]; then
### xdg-desktop-menu CAN NOT INSTALL A DIRECTORY FILE ON IT'S OWN! WHY EVER
### so we leave this code here until we know wtf is going on :)
### 		if [[ -n "$_xdg_desktop_menu_command" ]] ; then
### 			$_xdg_desktop_menu_command install --mode user "${_source}"
### 		else
###				cat "${_source}" > "${_target}"
### 		fi
		cat "${_source}" > "${_target}"
	fi
}

# --------------------------------------
# create a new entry in desktop start menu (such as kickoff)
# TODO check disabling flags here
# TODO with QEMU support the working part becomes a VMM specific thing.
#      If we just create a desktop file for qemu, we will take defaults from
#      JSON config and disk (absolute or relativ) path name as option to ME.
#      This disk image option actualy might be happy with the name without
#      extension. So it is similar to the VBOX variant.
function _create_desktop_entry() # $VM
{
	local _vm="$1"
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"
	VM_NAME="$_vm" # used in template

	_init_directory_entry

# 	if [[ $create_desktop_menu_entry_native_command ]]; then
# 		# use VMM template with native command set and function
# 		vmms::create_desktop_entry "$_vm"  # <---- THIS IS NOT A VMM THING!
# 	else
		# shellcheck disable=SC2034 # (used in template)
		VMMCON_DESKTOP_ENTRY_ICON=${create_desktop_menu_entry_icon:-computer-symbolic}
		# use global template with my command set
		_template_file="${MY_SHARE}/templates/xdg/${VMMCON_DESKTOP_ENTRY_TEMPLATE}"
		_template_content="$(cat "$_template_file")"
		### TODO: there are actualy two of these! there is also: ~/.gnome/apps/
		###       with a copy of my file, when created via xdg-desktop-menu(1).
		###       So we might either go for both directories and we might try
		###       xdg-desktop-menu(1) first and if this fails create manualy.
		_application_desktop_dir="${HOME}/.local/share/applications/${MY_NEW_NAME}"
		[ -d "${_application_desktop_dir}" ] || mkdir "${_application_desktop_dir}"
		#_application_desktop_dir_gnome="${HOME}/.gnome/apps"
		_application_desktop_filename="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
		_application_desktop_filepath="${_application_desktop_dir}/${_application_desktop_filename}"
		# create file from template ...
		[ -f "/tmp/${_application_desktop_filename}" ] && rm "/tmp/${_application_desktop_filename}"
		# TODO: use a "regular" mktemp file ??
		# TODO: wh do we use a temporary file at all !? likely because of the (commented) code just below, that relies on xdg-desktop-menu(1)
		eval "printf \"${_template_content}\"" > "/tmp/${_application_desktop_filename}" # this shell via eval can not write into existing file
# 		running internal command: create-desktop-entry Pop!_OS 21.04
# 		xdg-desktop-menu: filename 'org.vmmctl.vm.Pop__OS_21_04.desktop' does not have a proper vendor prefix
# 		A vendor prefix consists of alpha characters ([a-zA-Z]) and is terminated
# 		with a dash ("-"). An example filename is 'example-org.vmmctl.vm.Pop__OS_21_04.desktop'
# 		Use --novendor to override or 'xdg-desktop-menu --manual' for additional info.
#		xdg-desktop-menu(1) can not install into a subdiretory of ~/.local/share/applications
# 		_xdg_desktop_menu_command="$(type -p xdg-desktop-menu)"
# 		if [[ -n "$_xdg_desktop_menu_command" ]] ; then
# 			$_xdg_desktop_menu_command 'install' '--novendor' "/tmp/${_application_desktop_filename}"
# 		else
# 			cat "/tmp/${_application_desktop_filename}" > "${_application_desktop_filepath}"
# 		fi
		[[ -f "${_application_desktop_filepath}" ]] && rm "${_application_desktop_filepath}"
		cat "/tmp/${_application_desktop_filename}" > "${_application_desktop_filepath}"
		[[ -f "${_application_desktop_filepath}" ]] && echo "" >> "${_application_desktop_filepath}"
		[[ -f "${_application_desktop_filepath}" ]] && chmod 600 "${_application_desktop_filepath}"
		[[ -f "/tmp/${_application_desktop_filename}" ]] && rm "/tmp/${_application_desktop_filename}"
		# we might need to force menu cache building (after creating new vm lmde-6
		# the new vm didn't show up in the menu, although the file was there and looked okay)
		# https://userbase.kde.org/KDE_System_Administration/Caches
		# kbuildsycoca5
# 	fi
}

# --------------------------------------
# delete a formerly created entry in desktop start menu
function _delete_desktop_entry()
{
	local _vm="$1"
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"

	### TODO: there are actualy two of these! there is also: ~/.gnome/apps/
	###       with a copy of my file, when created via xdg-desktop-menu(1).
	###       So we might either go for both directories and we might try
	###       xdg-desktop-menu(1) first and if this fails create manualy.
	# temporary file name to create
	_application_desktop_dir="${HOME}/.local/share/applications/${MY_NEW_NAME}"
	#_application_desktop_dir_gnome="${HOME}/.gnome/apps"
	_application_desktop_filename="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
	_application_desktop_filepath="${_application_desktop_dir}/${_application_desktop_filename}"
	if [[ -f "${_application_desktop_filepath}" ]]; then
		# NOTE: xdg-desktop-menu seems to be very nitpicing about names, and as ours seems to not comply with the specs, the uninstall command does not delete the file
# 		_xdg_desktop_menu_command="$(type -p xdg-desktop-menu)"
# 		if [[ -n "${_xdg_desktop_menu_command}" ]] ; then
# 			${_xdg_desktop_menu_command} 'uninstall' "${_application_desktop_filename}"
# 		else
			rm -f "${_application_desktop_filepath}"
# 		fi
	else
		printf 'Application desktop file does not exists: %s\n' "${_application_desktop_filepath}" >&2
	fi
}

# --------------------------------------
# delete a formerly created entry in desktop start menu
function _search_desktop_entry()
{
	local _vm="$1"
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"
	_application_desktop_dir="${HOME}/.local/share/applications/vmmcon"
# 	_application_desktop_filename="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
	find "${_application_desktop_dir}" -name "${_my_vendor_prefix}.vm.*${_vm}*.desktop"
}

# --------------------------------------
# check if an iso image file is bootable
function _is_bootable_iso_image()
{
	local _iso="$1"
	file "$_iso" | grep -q -e '(bootable)$'
}
# ----- somethin similar possible to check if an iso requires EFI to boot?
# playtron alpha is an example



### commands instead of options.. (if after reading options first word is one of these)
#_default_command=create
#COMMAND=$_default_command
valid_commands=( \
"clone" \
"close" \
"commands" \
"create" \
"create-desktop-entry" \
"create-ssh-login" \
"create-group" \
"delete" \
"delete-desktop-entry" \
"delete-group" \
"destroy" \
"editrc" \
"enter" \
"export" \
"exec" \
"group" \
"halt" \
"help" \
"import" \
"info" \
"install" \
"move" \
"new" \
"launch" \
"list" \
"login" \
"open" \
"poweroff" \
"pause" \
"readdocs" \
"reboot" \
"remove" \
"rename" \
"reset" \
"restart" \
"run" \
"search" \
"search-desktop-entry" \
"shell" \
"shutdown" \
"snap" \
"start" \
"stop" \
"state" \
"status" \
"suspend" \
"ssh" \
"ungroup" \
"up" \
"view" \
)

# --------------------------------------
# Run a command as given on command line
function _run_command()
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
	#      Nutzung: ${_argv[1]}…
	#      _command=${_argv[0]}
	# TODO das kann alles außerhalb und vor dem Aufruf
	#      erledigt werden. command als erstes Argument
	#      den Rest als einzelne Argumente oder sogar
	#      als Array, dass als Name übergeben wird und
	#      mit declare(?) zu einem lokalem Array wird.
	local _argv=()
	while (( $# )); do
		_argv+=("$1")
		shift
	done
	_command="${_argv[0]}"
	# TODO: experimental idea to handle aliases, such as new | launch | up for 'create'
	declare -A command_aliases
	command_aliases[launch]='create'
	command_aliases[new]='create'
	command_aliases[up]='create'
	# wenn element in array, dann Wert als _command
	[[ -v command_aliases[$_command] ]] && _command="${command_aliases[$_command]}"
	# TODO are multiple statements of the same case allowed? this could be used
	#      to put all the startup parts into a common one for clone, import, create
	# TODO sort commands by name to find them easier
	case $_command in
		clone )
			_cloned=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			_vm="${_argv[1]}"
			_vm_clone="${_argv[2]}"
			[[ -n "$_vm" ]] || _error_exit "No existing vm name given ($LINENO)"
			[[ -n "$_vm_clone" ]] || _error_exit "No new vm name given ($LINENO)"
			[[ $_vm == "$_vm_clone" ]] || _error_exit "New vm name equals the source name ($LINENO)"
			vmms::vm_exists "${_vm}" || _error_exit "This VM does not exist: ${_vm} ($LINENO)"
			# TODO stopped is a minimum requirement. as the new VM will be
			#      assigned a new MAC it *shall* be not only rebooted, but powered
			#      of and on to get the new MAC addr applied to the OS as well.
			#      Cloning a stopped (i.e. "saved state") VM will create a clone
			#      with the same state. Starting this new clone, will not make it
			#      realizing the new MAC address and therefore ensure conflicts
			#      with the cloned system, as both are sharing the same MAC.
			#      Therefore a powered off VM is way more fool proove
			vmms::vm_is_powered_off "${_vm}" || _error_exit "Can not clone a running VM: ${_vm} ($LINENO)"
			printf '%s\n' 'Cloning may take a while. Be patient …'
			vmms::clone_vm "${_vm}" "${_vm_clone}" && _cloned=0 # IF we do! have a clone name we use it in the vmm spec. part
			if (( _cloned == 0 )); then
				_create_desktop_entry "${_vm_clone}" # "global" (set in vmms::clone_vm())
			fi
			### power this up?
			if ! $pwr; then
				if _ask_yes_no "New VM added: '${_vm_clone}'. Power up now?" "Power Up" "Not Yet"; then
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
		commands ) # just a simple list of commands for bash completion
			echo ${valid_commands[@]}
			_return=0
		;;
		create ) # hopefully now handled via new aliases construct
			_created=1
			### if filepath not set via option -f, use first argument instead
			if [[ -z "$filepath" ]]; then
				[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument or a filepath giving ($LINENO)"
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
						_verbose "Asking for iso file …" >&2
						filepath=$(_user_file_path "$dir")
						[[ -n "$filepath" ]] || _canceled_exit
						_verbose "\$filepath=$filepath" "[by user dialog]"
						break
					fi
				done
			fi
			### still no file path? > fail
			if [[ -z "$filepath" ]]; then
				_error_exit "No ISO image file given. Giving up. ($LINENO)"
			fi
			### check if we have anyfile and fail if not
			if [[ ! -f "$filepath" ]]; then
				_error_exit "Specified ISO image file does not exist:  $filepath. Giving up. ($LINENO)"
			fi
			# TODO this shall go into a function: _check_file_on_mime_type $file $mimetype
			### check on right mime type
			# TODO replace 'which' by either 'type' or 'command'
			xdg_mime=$(which xdg-mime) # TODO: use file -p instead?
			if [[ -n "$xdg_mime" ]]; then
				printf '%s\n' "checking mime type …" >&2
				mime_type="$($xdg_mime query filetype "$filepath" 2>/dev/null)"
				[[ "$mime_type" =~ application/x-cd-image ]] || [[ "$mime_type" =~ application/vnd.efi.iso ]] || [[ "$mime_type" =~ application/vnd.efi.img ]] || _error_exit "Specified image file does not fulfill one of these mime type requirements: 'application/x-cd-image, application/vnd.efi.iso, application/vnd.efi.img'. Giving up ($LINENO)"
			fi
			### check if we have a valid ISO file and fail if not
			#
			# TODO replace 'which' by either 'type' or 'command'
			#
			isovfy="$(which isovfy)" # TODO: use file -p instead?
			if [[ -n "$isovfy" ]]; then
				printf '%s\n' "Veryfying image file …" >&2
				$isovfy "$filepath" >/dev/null 2>&1 || _error_exit "Specified file could not be veryfied as a valid image. Giving up ($LINENO)" # note: verifies IMG files as well
			fi
			### use filename as in filepath to search for a profile
			filename="${filepath##*/}"
			_verbose filename="$filename"
			### inform the user*in"
# 			if [[ $yes = true ]]; then
# 			if $yes ; then
# 				:
# 			else
# 				if ! _ask_yes_no "Create virtual machine from \"$filename\"?" "Create" "Cancel"; then
# 					_canceled_exit
# 				fi
# 			fi
			### create a simple suggestion for the vm name from ISO image file name
			_vm_name_suggest="${filename%.*}"
			_vm_name_suggest="${vm_name:-$_vm_name_suggest}"
			_verbose "STAMP=${STAMP}" >&2
			if $create_stamp; then
				if [[ -n "${STAMP}" ]]; then
					_vm_name_suggest="${_vm_name_suggest}${STAMP}"
				else
					_vm_name_suggest="${_vm_name_suggest}-${TODAY}"
				fi
			fi
			### get a name for the new virtual machine
			if $yes ; then
				vm_name="$_vm_name_suggest"
			else
				# unfortunately kdialog --imginputbox does not respect additional preset text as --inputbox does,
				# so we can not use a nice icon here: "$BIN_DIR/${MY_NAME}.d/icons.d/display-and-tower.svg"
				# extra spaces trainling the proposed text are required as kdialog does not respect the text length
# 				vm_name=$(_ask_vm_name "$_vm_name_suggest")
				vm_name=$(_create_and_ask_vm_name "$filename" "$_vm_name_suggest")
				if [[ -z "$vm_name" ]]; then
					_canceled_exit
				fi
			fi
			### check existence if vm name was given on command line
			vmms::vm_exists "$vm_name" \
				&& _error_exit "VM already exists: \"$vm_name\". giving up. ($LINENO)"
			### automagic profile search (if set)
			if [[ -z "$profile" ]]; then
				if $auto; then
					if [[ -f "$automagic_table_local" ]]; then
						printf '%s\n' "Reading automacic local table: $automagic_table_local" >&2
						read -r match profile < <(_auto_profile "$filename" "$automagic_table_local")
					fi
					if [[ -z "$profile" ]]; then
						printf '%s\n' "Reading automacic table: $automagic_table" >&2
						read -r match profile < <(_auto_profile "$filename" "$automagic_table")
					fi
					if [[ -z "$profile" ]]; then
						_error_exit "Auto profile match failed, must quit ($LINENO)" 9
					else
						printf '%s\n' "Auto matched profile: $profile" >&2
					fi
				fi
			fi
			### if no templete given and auto false we ask the userin for a profile
			if [[ -z "$profile" ]]; then
# 				if $select; then
					### ask user what profile to use or cancel
					profile=$(_user_profile)
					### no profile? userin has canceled
					test -n "$profile" || _canceled_exit
					### save bed test as above. generaly never reached out
					if [[ -z "$profile" ]]; then
						_error_exit "No profile selected, must quit ($LINENO)" 9
					else
						printf '%s\n' "User selected profile: $profile" >&2
					fi
# 				fi
			fi
			### no profile .. give up (TODO: or use a super dummy default?)
			if [[ -z "${profile}"  && -z "${match}" ]]; then
				_error_exit "No profile, must quit ($LINENO)" 9
			fi
			### be informative if wanted
			[[ -n $match ]] && printf 'Using match: %s\n' "$match" >&2
			[[ -n $profile ]] && printf 'Using profile: %s\n' "$profile" >&2
			### run profile config file, if it is there, warn on failure if not
			profile_conf="${PROFILES_DIR}/${profile}.conf"
			if [[ -f "$profile_conf" ]]; then # TODO reverse test to ! and save code lines
				printf '%s\n' "Using profile config: $profile_conf" >&2
				# shellcheck disable=SC1090
				. "$profile_conf"
# 			else
# 				_warning "profile does not exist: '$profile_conf'. Continue with fallback 'linux'?" || _canceled_exit
# 				conf="${PROFILES_DIR}/linux.conf"
# 				if [[ -f "$profile_conf" ]]; then
# 					printf '%s\n' "Running fallback config: $profile_conf" >&2
# 					# shellcheck disable=SC1090
# 					. "$profile_conf"
# 				fi
			fi
# 			### run local profile config file, if it is there
# 			local_conf="${PROFILES_DIR_LOCAL}/${profile}.conf"
# 			if [[ -f "$local_conf" ]]; then
# 				printf '%s\n' "Running local config: $local_conf" >&2
# 				# shellcheck disable=SC1090
# 				. "$local_conf"
# 			else
# 				:
# 			fi
			### use match to include a distro name based configuration
			match_conf="${MATCHES_DIR}/${match}.conf"
			if [[ -f "$match_conf" ]]; then
				printf '%s\n' "Running match config: $match_conf" >&2
				# shellcheck disable=SC1090
				. "$match_conf"
			else
				:
			fi
			### try to modify architecture for 32-bit OSs
# 			if [[ $filename =~ *i386* || $filename =~ *32bit* ]]; then
			if [[ $filename = *i386* || $filename = *32bit* ]]; then # recommended by shellcheck SC2049 (regular expression v. glob)
				vm_ostype="${vm_ostype%_64}"
				# shellcheck disable=SC2034
				vm_firmware="bios" # new naming style? vmms_vm_firmware=...
			fi
			### if not set explicitly compute VMs cpu count from host
			vm_cpu_count=$(_init_vm_cpu_count)
			### if not set explicitly compute VMs memory size from host
			vm_memory_size=$(_init_vm_memory_size)
			### evaluate command line options
			for key in ${!command_line_configs[*]}; do
# 				printf "using: ${key}='${command_line_configs[$key]}'\n" >&2
				printf 'using: %s=%s\n' "${key}" "${command_line_configs[$key]}" >&2
				eval "${key}"="${command_line_configs[$key]}"
			done
			### let the show begin…
			_notify "Creating new VM" "\"$vm_name\" …"
			
			
			# TODO: switch by mimetype of file
			case $mime_type in
				application/x-cd-image | application/vnd.efi.iso )
					printf "creating vm with bootable iso image...\n"
					vmms::create_vm_from_iso_image "$vm_name" && _created=0
				;;
				application/vnd.efi.img )
					printf "creating vm with disk from raw image...\n"
					vmms::create_vm_with_disk_image "$vm_name" && _created=0
				;;
				* )
				  _error_exit "Unknown or unsupported mime type ($LINENO): $mime_type"
				  _return=1
				;;
			esac
			
			
			### create desktop entry for starts from start menu
			if (( _created == 0 )); then
				if $create_desktop_menu_entry; then
					$dry || _create_desktop_entry "$vm_name"
				fi
			fi
			### desktop 'notification' on success and eventualy power the box up
			if $yes; then
				pwr=true
			fi
			if ! $pwr; then
				if _ask_yes_no "New VM added: '$vm_name'. Power up now?" 'Power Up' 'Not Yet'; then
					pwr=true
				fi
			fi
			if $pwr; then
				### run vbox, run
				vmms::start_vm "$vm_name"
			else
				_notify "New VM not started"
			fi
			_exit=$_created
			_return=$_created
		;;
		create-desktop-entry )
			# TODO (from config) #create_desktop_menu_entry=false # not to be evaluated here!
			_created=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			# TODO this shall not create desktop entries for non existing machines
			# TODO exit if argument is not given (is this handled elsewehere? i guess not!
			$dry || _create_desktop_entry "${_argv[1]}" && _created=0
			_exit=$_created
			_return=$_created
		;;
		create-group )
			:
		;;
		create-ssh-login )
			_created=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			$dry || vmms::create_vm_ssh_login "${_argv[1]}" && _created=0
			_exit=$_created
			_return=$_created
		;;
		delete | destroy | remove )
			### to delete an existing vm an exact(!) name is required
			# TODO implement --dry (here or in the functions script?)
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires at least one argument ($LINENO)"
			for _vm in "${_argv[@]:1}"; do # pop the first element
				_deleted=1
# 				_vm="${_argv[1]}"
				vmms::vm_exists "${_vm}" || _error_exit "This VM does not exist: ${_vm} ($LINENO)" # --quiet?
				vmms::vm_is_stopped "${_vm}" || _error_exit "Can not delete a running VM: ${_vm} ($LINENO)" # --quiet?
# 				if [[ $yes = true ]]; then
				if $yes; then
					vmms::delete_vm "${_vm}" && _deleted=0
				else
					_warning "Delete VM: '${_vm}'" && vmms::delete_vm "${_vm}" && _deleted=0
				fi
				### delete desktop entry for starts from start menu
				if (( _deleted == 0 )); then
					$dry || _delete_desktop_entry "$_vm"
				fi
			done
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
		delete-group )
			:
		;;
		editrc )
			# howto detect if editor requires a console emulation? (such as vi, micro or nano)
			# we look for these well known names and run these in an emulation
			# if none of these names is configured, we look for less documented option *_run_in_terminal
			# final default is to start the application assuming in it's own window..
			case "$vmmcon_defaults_editor" in
				vi | vim | micro | nano )
					if $gui; then
						konsole -e "$vmmcon_defaults_editor" "$MY_RC"
					else
						$vmmcon_defaults_editor "$MY_RC"
					fi
				;;
				* )
					if $vmmcon_defaults_editor_run_in_terminal; then
						konsole -e "$vmmcon_defaults_editor" "$MY_RC"
					else
						$vmmcon_defaults_editor "$MY_RC"
					fi
				;;
			esac
			_exit=0
			_return=0
		;;
		exec )
			### NOTE: to avoid password entering: $ ssh-copy-id -p 56308 $LOGNAME@localhost
			_executed=1
			[[ -z "${_argv[2]+x}" ]] && _error_exit "This command requires at least two arguments minimum ($LINENO)"
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			_vm_host_ssh_port=$(vmms::get_ssh_port "${_vm}")
			_vm_tcp_ssh_username="$(vmms::get_ssh_username "${_vm}")"
			### remove first item in argv (pop) which is 'exec' and vm name
# 			unset _argv[0] # not quite right
			_argv=("${_argv[@]:2}")
			### remove vm name
# 			_argv=("${_argv[@]:1}")
			### remove (if present) '--'
			[[ ${_argv[0]} == '--' ]] && _argv=("${_argv[@]:1}")
			### remaning arguments shall be executed remotly
			if [[ -n "${_vm_host_ssh_port}" ]]; then
				echo "running: ssh -p ${_vm_host_ssh_port} ${_vm_tcp_ssh_username}@localhost \"${_argv[*]}\"" 1>&2
				ssh -p "${_vm_host_ssh_port}" "${_vm_tcp_ssh_username}@localhost" "${_argv[0]}"; _executed=$?
				_return=$?
			else
				_error_exit "VM ssh port is not set, must quit ($LINENO)"
				_return=9
			fi
		;;
		export ) # WARNING NOT TESTED AT ALL. THIS IS JUST A FIRST DRAFT
			_exported=1
			### if filepath not set via option -f, use first argument instead
			if [[ -z "$filepath" ]]; then
				[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument or a filepath give mith option -f ($LINENO)"
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
			vmms::vm_exists "${_argv[1]}" || _error_exit "This VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
			vmms::vm_is_stopped "${_argv[1]}" || _error_exit "Can not export a running VM: ${_argv[1]} ($LINENO)" # --quiet?

			# TDOO: check if file exists, ask to overwrite (e.e. delete now) or cancel

			vmms::export_vm "${_vm}" "$filepath" && _exported=0
			_exit=$_exported
			_return=$_exported
		;;
		group )
			# if group does not exists .. it will be created on the fly
			_grouped=1
			[[ -z "${_argv[2]+x}" ]] && _error_exit "This command requires two arguments minimum ($LINENO)"
			# TODO: array slicing might help getting the job done (no need to get the last index manualy)
			_argv_length=${#_argv[@]}
# 			echo _argv_length: $_argv_length
			_last_index=$((_argv_length - 1))
			# TODO: check for group name starting with a '/'
			_vm_group="${_argv[$_last_index]}"
# 			echo _vm_group: $_vm_group
			for ((n = 1; n < _last_index; n++))
			do
				_vm_pattern="${_argv[$n]}"
				# TODO: if pattern matching works fine, the exact match (on existence) is not required
				if vmms::vm_exists "${_vm_pattern}"; then
					_vm="${_vm_pattern}"
					vmms::move_vm_to_group "${_vm}" "${_vm_group}"
					_grouped=$?
				else
					# if list by pattern > 1, then loop
					readarray -t _vm_list < <(vmms::query_vm "${_vm_pattern}")
#	 				echo '${_vm_list[@]}': ${_vm_list[@]}
					for _vm in "${_vm_list[@]}"
					do
						printf 'moving _vm: %s\n' "$_vm" >&2
						vmms::move_vm_to_group "${_vm}" "${_vm_group}"
						_grouped=$?
					done
				fi
			done
			_return=$_grouped
		;;
		# stop system by trying to send ACPI stop command
		halt | poweroff | shutdown )
			_off=1
			_vm="${_argv[1]}"
			vmms::vm_exists "${_argv[1]}" || _error_exit "This VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
			vmms::vm_is_stopped "${_argv[1]}" || _error_exit "Can not power off a stopped VM: ${_argv[1]} ($LINENO)" # --quiet?
			vmms::acpi_power_off_vm "${_vm}" && _off=0 
			_exit=$_off
			_return=$_off
		;;
		help )
			_usage
			_exit=0
			_return=0
		;;
		import )
			_imported=1
			### if filepath not set via option -f, use first argument instead
			if [[ -z "$filepath" ]]; then
				[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument or a filepath giving via option -f ($LINENO)"
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
# 			_verbose filename="$filename"
			### inform the user*in"
# 			if [[ $yes = true ]]; then
			if $yes ; then
				:
			else
				if ! _ask_yes_no "Import Appliance from \"$filename\"?" "Import" "Cancel"; then
					_canceled_exit
				fi
			fi
			#
			# TODO: clean up this mess.  same code is found ~ line 1319
			#
			### create a simple suggestion for the vm name from ISO image file name
			_vm_name_suggest="${filename%.*}"
			_vm_name_suggest="${vm_name:-$_vm_name_suggest}"
			_verbose "STAMP=${STAMP}" >&2
			if $create_stamp; then
				if [[ -n "${STAMP}" ]]; then
					_vm_name_suggest="${_vm_name_suggest}${STAMP}"
				else
					_vm_name_suggest="${_vm_name_suggest}-${TODAY}"
				fi
			fi
			_verbose "_vm_name_suggest=$_vm_name_suggest" >&2
			### get a name for the new virtual machine
			if [[ $yes = true ]]; then
				vm_name="$_vm_name_suggest"
			else
				# unfortunately kdialog --imginputbox does not respect additional preset text as --inputbox does,
				# so we can not use a nice icon here: "$BIN_DIR/${MY_NAME}.d/icons.d/display-and-tower.svg"
				# extra spaces trainling the proposed text are required as kdialog does not respect the text length
				if ! vm_name=$(_ask_vm_name "$_vm_name_suggest"); then
					_canceled_exit
				fi
			fi
			### let the show begin…
			_notify "Importing Appliance as VM" "\"$vm_name\" …"
			vmms::import_applicance "$filepath" "$vm_name" && _imported=0
			### create desktop entry for starts from start menu
			if (( _imported == 0 )); then
				_create_desktop_entry "$vm_name"
			fi
			### desktop 'notification' on success and eventualy power the box up
			if ! $pwr; then
				if _ask_yes_no "New VM added: '$vm_name'. Power up now?" "Power Up" "Not Yet"; then
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
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
# 			_vm="${_argv[1]}"
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			vmms::vm_exists "${_vm}" || _error_exit "This VM does not exist: ${_vm} ($LINENO)" # --quiet?
			vmms::vm_info "${_vm}"
			_exit=0
			_return=0
		;;
		list )
			# TODO: use -l for vms with group names? or -g?
# 			[[ -z "${_argv[1]+x}" ]] || _error_exit "This command do *not* require an argument. 
#			you might want 'search' instead to search for a VM ($LINENO)"
			if [[ -z "${_argv[1]+x}" ]]; then
				# no argument given
				if $list_running; then
					vmms::list_vms_running
				elif $list_stopped; then
					vmms::list_vms_stopped
				else
					vmms::list_vms
				fi
				_exit=0
				_return=0
			else
				# at least one argument given (search)
				_matched=1
				vmms::query_vm "${_argv[1]}" && _matched=0
				_exit=$_matched
				_return=$_matched
			fi
		;;
		login | ssh | enter | shell )
# 			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
			# TODO obviously this won't work with more than just one running VM :(
			# DONE we now use random port numbers and store them in extended data
			#      we might enable the rule on the fly with controlvm
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			_vm_host_ssh_port=$(vmms::get_ssh_port "${_vm}")
			_vm_tcp_ssh_username="$(vmms::get_ssh_username "${_vm}")"
			typeset -u _vm_net_mode="$(vmms::get_vm_network_mode "${_vm}")"
			case "${_vm_net_mode}" in
				'NAT' )
					if [[ -n "${_vm_host_ssh_port}" ]]; then
						printf '%s\n' "running: ssh -p ${_vm_host_ssh_port} ${_vm_tcp_ssh_username}@localhost"
						printf '%s\n' "if you want to avoid any password request when login, try this command:"
						printf '%s\n' "$ ssh-copy-id -p 36719 christian@localhost"
						ssh -p "${_vm_host_ssh_port}" "${_vm_tcp_ssh_username}@localhost"
						_return=$?
					else
						_error_exit "VM ssh port is not set, must quit ($LINENO)"
						_return=9
					fi
				;;
				'BRIDGED' )
					_vm_ip="$(vmms::get_vm_bridged_ip_addr "${_vm}")"
						printf '%s\n' "running: ssh ${_vm_tcp_ssh_username}@${_vm_ip}"
						printf '%s\n' "if you want to avoid any password request when login, try this command:"
						printf '%s\n' "$ ssh-copy-id christian@${_vm_ip}"
					ssh "${_vm_tcp_ssh_username}@${_vm_ip}"
					_return=$?
				;;
				* )
					_error_exit "unknown networking mode ($LINENO): '$_vm_net_mode'. Must quit"
					_return=9
				;;
			esac
		;;
		move ) # TODO move into a group or from a group
			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
			_return=1
		;;
		open ) # redefined as open a http connection 
			_opened=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			# TODO stop if we do not have a matching vm
			vmms::vm_is_stopped "${_vm}" && _error_exit "Can not open a stopped VM: ${_vm} ($LINENO)"
			_open_protocol=${open_protocol:='https'}
# 			vmms::open_vm "${_vm}" "${_open_protocol}" && _opened=0
			case ${_open_protocol} in
				http )
					_open_port=$(_vbox_manage 3 getextradata "$_vm" 'vmmcon-tcp-http-port' | sed 's/[^0-9]//g')
# 					_open_port=$(vmms::get_port "${_vm}" "${_open_protocol}")
				;;
				https )
					_open_port=$(_vbox_manage 3 getextradata "$_vm" 'vmmcon-tcp-https-port' | sed 's/[^0-9]//g')
# 					_open_port=$(vmms::get_port "${_vm}" "${_open_protocol}")
				;;
				ssh )
					_open_port=$(vmms::get_ssh_port "${_vm}")
# 					_open_port=$(vmms::get_port "${_vm}" "${_open_protocol}")
				;;
				* )
				;;
			esac
			if [[ -z "$_open_port" ]]; then
				_error_exit "port for protocol '${_open_protocol}' is not set in vbox extra data"
			fi
# 			printf '%s\n' "Opening '${_open_protocol}' connection to '${_vm}' at port '${_open_port}' …" >&2
			printf 'Opening %s connection to %s at port %s …\n' "${_open_protocol}" "${_vm}" "${_open_port}" >&2
			case ${_open_protocol} in
				http | https )
					_url=$(vmms::open_vm "${_vm}" "${_open_protocol}")
					xdg-open "${_url}" && _opened=0 # x-www-browser is a valid alternative (at least for Debian)
				;;
				ssh )
					_vm_tcp_ssh_username="${vm_tcp_ssh_username:-$LOGNAME}"
					ssh -p "${_open_port}" "${_vm_tcp_ssh_username}@localhost" && _opened=0
				;;
			esac
			_exit=$_opened
			_return=$_opened
		;;
		pause )
			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
		;;
		readdocs )
			# TODO own set of DE agnostic commands to replace kioclient (here)
# 			xdg-open "$MY_GIT_HOME" # this should work, but it doesn't
			kioclient exec "$MY_GIT_HOME" 2>/dev/null
			_exit=0
			_return=0
		;;
		reboot | restart )
			_error_exit "Command not yet implesearchmented ($LINENO): '$_command'. Realy sorry"
			_return=1
		;;
		remove )
			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
		;;
		### NOTE: move is *not* propagated synonym for rename as the term might be used in future 
		###       implementations to "physically" move a VM to a different storage location
		rename )
			_renamed=1
			[[ -z "${_argv[2]+x}" ]] && _error_exit "This command requires two arguments ($LINENO)"
			_vm_old_name="${_argv[1]}"
			_vm_new_name="${_argv[2]}"
			[[ -n "${_vm_old_name}" ]] || _error_exit "No existing vm name given ($LINENO)"
			[[ -n "${_vm_new_name}" ]] || _error_exit "No new vm name given ($LINENO)"
			[[ "${_vm_old_name}" == "${_vm_new_name}" ]] && _error_exit "New vm name equals the old name ($LINENO)"
			vmms::vm_exists "${_vm_old_name}" || _error_exit "This VM does not exist: ${_vm_old_name} ($LINENO)" # --quiet?
			vmms::vm_is_stopped "${_vm_old_name}" || _error_exit "Can not rename a running VM: ${_vm_old_name} ($LINENO)" # --quiet?
			vmms::rename_vm "${_vm_old_name}" "${_vm_new_name}" && _renamed=0
			### delete and create desktop entry for starts from start menu
			# TODO there might be somethin gwrong with the test
			# TODO it might be the _delete part of it
			if (( _renamed == 0 )); then
				_delete_desktop_entry "${_vm_old_name}"
				_create_desktop_entry "${_vm_new_name}"
			fi
			_exit=$_renamed
			_return=$_renamed
		;;
		reset | discardstate | purge )
			_purged=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			_vm="${_argv[1]}"
			vmms::vm_exists "${_vm}" || _error_exit "This VM does not exist: ${_vm} ($LINENO)"
			vmms::vm_is_stopped "${_vm}" || _error_exit "Can not purge state of a running VM: ${_vm} ($LINENO)"
			vmms::vm_has_saved_state "${_vm}" || _error_exit "Can not purge state of VM without such saved state: ${_vm} ($LINENO)"
			if $yes; then
				vmms::purge_vm_saved_state "${_vm}" && _purged=0
			else
				_warning "Delete VM saved state: '${_vm}'" && vmms::purge_vm_saved_state "${_vm}" && _purged=0
			fi
			_return=$_purged
		;;
		resume | restore ) # from a 'paused' or 'suspended' state
			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
		;;
		'search' )
			_matched=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			_vm="${_argv[1]}"
			if $list_running; then
				_function="vmms::list_vms_running"
			elif $list_stopped; then
				_function="vmms::list_vms_stopped"
			else
				_function="vmms::list_vms"
			fi
			$_function | grep -i "${_vm}" && _matched=0
			_exit=$_matched
			_return=$_matched
		;;
		search-desktop-entry )
			_matched=1
			$dry || _search_desktop_entry "${_argv[1]}" && _matched=0
			_exit=$_matched
			_return=$_matched
		;;
		snap | snapshot )
			### NOTE the vbox snapshot command has a --live option to allow snapshots from running VMs, but we do not recommend to trust on this
			_snapped=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
			printf 'searching %s …\n' "${_argv[1]}" >&2
			_vm="$(vmms::query_vm "${_argv[1]}" | head -1)"
			[[ -n "$_vm" ]] || _error_exit "There is no VM matching: '${_argv[1]}' ($LINENO)"
# 			vmms::vm_is_stopped "${_vm}" || _error_exit "Can not snap a running VM: ${_vm} ($LINENO)"
			printf 'snapping %s …\n' "${_vm}" >&2
			vmms::snap_vm "${_vm}" && _snapped=0
			_exit=$_snapped
			_return=$_snapped
		;;
		start | run )
			_started=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "This VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_stopped "${_argv[1]}" || _error_exit "Can not start a running VM: ${_argv[1]} ($LINENO)"
# 			vmms::start_vm "${_argv[1]}" && _started=0
			# exact match has precedence
			if vmms::vm_exists "${_argv[1]}"; then
				vmms::vm_is_stopped "${_argv[1]}" || _error_exit "Can not start a running VM: ${_argv[1]} ($LINENO)"
				vmms::start_vm "${_argv[1]}" && _started=0
			else
				# behave like query/search
				printf 'searching %s …\n' "${_argv[1]}" >&2
# 				vmms::query_vm "${_argv[1]}"
#				vmms::query_vm "${_argv[1]}" | head -1
				  _vm="$(vmms::query_vm "${_argv[1]}" | head -1)"
# 				echo "found $_vm" >&2
				[[ -n "$_vm" ]] || _error_exit "There is no VM matching: '${_argv[1]}' ($LINENO)"
				vmms::vm_is_stopped "${_vm}" || _error_exit "Can not start a running VM: ${_vm} ($LINENO)"
				printf 'starting %s …\n' "${_vm}" >&2
				vmms::start_vm "${_vm}" && _started=0
			fi
			_exit=$_started
			_return=$_started
		;;
		state | status )
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
# 			vmms::vm_exists "${_argv[1]}" && printf '%s\n' "vm exists"
# 			vmms::vm_is_running "${_argv[1]}" && printf '%s\n' "vm is running"tatus
# 			vmms::vm_is_stopped "${_argv[1]}" && printf '%s\n' "vm is stopped"
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			vmms::vm_is_running "${_vm}" && printf '%s\n' "vm is running"
			vmms::vm_is_stopped "${_vm}" && printf '%s\n' "vm is stopped"
			_exit=0
			_return=0
		;;
		stop )
			_stopped=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "This VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_running "${_argv[1]}" || _error_exit "Can not stop a stopped VM: ${_argv[1]} ($LINENO)"
# 			vmms::stop_vm "${_argv[1]}" && _stopped=0
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			[[ -n "${_vm}" ]] || _error_exit "There is no VM matching: ${_argv[1]} ($LINENO)"
			vmms::vm_is_running "${_vm}" || _error_exit "Can not stop a stopped VM: ${_vm} ($LINENO)"
			vmms::stop_vm "${_vm}" && _stopped=0
			_exit=$_stopped
			_return=$_stopped
		;;
		'suspend' ) # '' to indicate this as a fixed string?
			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
		;;
		ungroup )
			# if group is empty after removing vm, it will be deleted
			_ungrouped=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires one argument minimum ($LINENO)"
			# TODO: array slicing might help getting the job done (no need to get the last index manualy)
			_argv_length=${#_argv[@]}
			_last_index=$((_argv_length - 1))
			for ((n = 1; n == _last_index; n++))
			do
				_vm_pattern="${_argv[$n]}"
				readarray -t _vm_list < <(vmms::query_vm "$_vm_pattern")
				for _vm in "${_vm_list[@]}"
				do
					vmms::remove_vm_from_group "${_vm}"
					_grouped=$?
				done
			done
			_return=$_ungrouped
		;;
		update ) # me from github?
			_error_exit "Command not yet implemented ($LINENO): '$_command'. Realy sorry"
		;;
		view )
			_viewing=1
			[[ -z "${_argv[1]+x}" ]] && _error_exit "This command requires an argument ($LINENO)"
# 			vmms::vm_exists "${_argv[1]}" || _error_exit "This VM does not exist: ${_argv[1]} ($LINENO)" # --quiet?
# 			vmms::vm_is_running "${_argv[1]}" || _error_exit "Can not start a running VM: ${_argv[1]} ($LINENO)"
# 			vmms::view_vm "${_argv[1]}" && _viewing=0
			_vm=$(vmms::query_vm "${_argv[1]}" | head -1)
			[[ -n "${_vm}" ]] || _error_exit "There is no VM matching: ${_argv[1]} ($LINENO)"
			vmms::vm_is_running "${_vm}" || _error_exit "Can not start a running VM: ${_vm} ($LINENO)"
			vmms::view_vm "${_vm}" && _viewing=0
			_exit=$_viewing
			_return=$_viewing
		;;
		* )
			_error_exit "Unknown command ($LINENO): $_command"
			_usage
			_return=1
		;;
	esac
	# TODO return or exit? this is (called) function, so return
# 	printf '\n' >&2
# 	exit $_exit
	return $_return
}



### check for help or version options (only options allowed instead of a command)
if [[ $# -gt 0 ]]; then
	case "$1" in
		-h | --help )
			_usage
			exit 0
		;;
		-V | --version )
			printf '%s\n' "${VERSION}"
			exit 0
		;;
	esac
fi

### warm welcome (and test of localization)
# printf "$(gettext 'Welcome to'): ${MY_TITLE} \n"
# printf "$(gettext 'Version'): ${VERSION}\n"
# printf "$(gettext 'Welcome to'): ${MY_TITLE} Version: ${VERSION}\n"
# printf '%s v%s\n' "${MY_TITLE}" "${VERSION}" >&2

### import vmm based interface set
if [[ -v VMM ]]; then
	if [[ -f "${VMMS_DIR}/${VMM}/functions.sh" ]]; then
		# shellcheck disable=SC1090
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

### EVALUATE COMMMANDS BEFORE OPTIONS!
### there is just one allowed and it must preceed all other words on command line
if [[ $# -gt 0 ]]; then
	given_comand="$1"
else
	_plain_exit "$MY_NEW_NAME requires a command. try '$MY_NEW_NAME help' for a list of commands"
fi
# for command in ${valid_commands[*]}; do
for command in "${valid_commands[@]}"; do
	if [[ $# -gt 0 ]]; then
		if [[ ${command} == "$given_comand" ]] ; then
			COMMAND="$given_comand"
			shift 1
			break
		fi
	fi
done

if [[ ! -v COMMAND ]]; then
# 	if [[ $# -gt 0 ]]; then
		printf '\n%s\n' "ERROR: '$given_comand' is not a valid command"
		printf '\n%s\n\n' "Try '$MY_NEW_NAME help' for a list of valid commands and options"
		exit 99
# 	else
# 		printf '\n%s\n' "ERROR: $MY_NEW_NAME requires at least one valid command"
# 		printf '\n%s\n\n' "Use $MY_NEW_NAME 'help' for a list of commands and options"
# 		exit 99
# 	fi
fi

### get profile and file name from command line
tmpl=false

### dynamic config values via command line
declare -A command_line_configs
valid_options=$(getopt \
-o \
aCdE:f:GhI:i:Nn:o:P:prS:sTtuVvxy \
--long \
auto,\
auto-magic,\
cli,\
force-cli,\
debug,\
desktop,\
dry-run,\
file:,\
from:,\
gui,\
force-gui,\
help,\
human,\
iso:,\
isofile:,\
isoimage:,\
libvirt,\
name:,\
no-auto,\
option:,\
output:,\
power,\
power-up,\
profile:,\
qemu,\
run,\
running,\
select,\
ssh,\
start,\
stamp:,\
stopped,\
terminal,\
tui,\
force-tui,\
version,\
vbox,\
verbose,\
virsh,\
vmm:,\
yes \
-- "$@")

### did getopt parsed nicely?
# shellcheck disable=SC2181
if [[ $? -ne 0 ]]; then
	error_txt="$(gettext "has more information")"
	printf '%s help %s\n' "$MY_NAME" "$error_txt" >&2
	exit 1
fi

### init the evaluation loop
eval set -- "$valid_options"

### evaluate remaining command line options (if any remains)
# while [ : ]; do
while [[ $# -gt 0 ]]; do
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
		_debug OPTARG="${OPTARG}" >&2
	fi
	case $OPT in
		-a | --auto | --auto-magic | --auto-profile )
			_verbose "Running in automagic mode …" >&2
			# shellcheck disable=SC2034
			auto=true
			_verbose "auto=$auto"
			shift
		;;
		-C | --cli | --force-cli )
			_verbose "Running in forced cli mode …" >&2
			cli=true
			gui=false
			tui=false
			shift
		;;
		--desktop )
			# shellcheck disable=SC2034
			desktop=true
			_verbose "desktop=$desktop"
			shift
		;;
		-d | --dry-run )
			_verbose "Running in dry mode …\n" >&2
			# shellcheck disable=SC2034
			dry=true
			_verbose "dry=$dry"
			shift
		;;
		-G | --gui | --force-gui )
			_verbose "Running in forced gui mode …" >&2
			gui=true
			cli=false
			shift
		;;
# 		-h | --help )
# 			_usage
# 			exit 0
# 		;;
		-i | --iso | --isofile | --isoimage | -f | --file | --from )
			_verbose "f=${OPTARG}" >&2
			filepath="${OPTARG}"
			_verbose "\$filepath=$filepath [by option]"
			shift 2
		;;
		--http )
			open_protocol='http'
			shift
		;;
		--https )
			open_protocol='https'
			shift
		;;
		--human )
			# NOTE: currently not used
			# shellcheck disable=SC2034
			human_readable=true
			shift
		;;
		--libvirt )
			VMM=libvirt
			shift
		;;
		-N | --no-auto )
			shift
		;;
		-n | --name )
			_verbose "n=${OPTARG}" >&2
			vm_name="${OPTARG}"
			shift 2
		;;
		-o | --option )
			_verbose "o=${OPTARG}" >&2
			### put this in a stack and execute later after reading confs and
			### profiles after a minimal check on validity
			if [[ "${OPTARG}" =~ [a-z]=.? ]]; then
				option_key="${OPTARG%%=*}"
				option_value="${OPTARG#*=}"
				command_line_configs[$option_key]="$option_value"
				_verbose "${!command_line_configs[*]}" >&2
				_verbose "${command_line_configs[*]}" >&2
			else
				_verbose "option \"${OPTARG}\" ignored because of invalid syntax. should be foo=\"bar\"" >&2
			fi
			shift 2
		;;
		--out | --output )
# 			_verbose "f=${OPTARG}" >&2
			filepath="${OPTARG}"
# 			_verbose "\$filepath=$filepath [by --output]"
			shift 2
		;;
		-p | --profile )
			_verbose "t=${OPTARG}"
			profile="${OPTARG}"
			declare -l tmpl_cand
			# check valid profile name by existence of profile file (allowed to be empty)
# 			for conf in "${PROFILES_DIR}"/?*.conf "${PROFILES_DIR_LOCAL}"/?*.conf; do
			for conf in "${PROFILES_DIR}"/?*.conf; do
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
		--qemu )
			VMM=qemu
			shift
		;;
		# TODO: intentionaly to get replaced by 'launch' command
		--run | --start ) # same as power, power-up
			# power up after creating
			# shellcheck disable=SC2034
			pwr=true
			_verbose "pwr=$pwr"
			shift
		;;
		--running )
			list_running=true
			shift
		;;
		-s | --select ) # default behavior
			select=true
			shift 1
		;;
		-S | --stamp )
			STAMP="${OPTARG}"
			shift 2
		;;
		--ssh )
			open_protocol='ssh'
			shift
		;;
		--stopped )
			list_stopped=true
			shift
		;;
		-t | --terminal )
			# TODO: ignore if called inside a terminal: test -t 0 might do the trick. it does!
			test -t 0 || terminal=true
			shift
		;;
		-T | --tui | --force-tui )
			_verbose "Running in forced tui mode …" >&2
			tui=true
			gui=false
			cli=false
			shift
		;;
		-u | --power | --power-up )
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
# 		-V | --version )
# 			printf '%s\n' "Version: ${VERSION}" >&2
# 			exit 0
# 		;;
		-v | --verbose )
			printf '%s\n'  "enabling verbose mode …" >&2
			VERBOSE=true
			shift
		;;
		--virsh )
			VMM=libvirt
			shift
		;;
		--vmm )
			VMM=${OPTARG}
			shift 2
		;;
		-X )
			### legacy option
			gui=true
			cli=false
			shift
		;;
		-x | --debug )
			_verbose "enabling DEBUG mode …" >&2
			DEBUG=true
			shift
		;;
		-y | --yes )
			_verbose "enabling unattended mode …" >&2
			yes=true
			_verbose "y=$yes"
			shift
		;;
		### anything else is an usage error (but caught already above by getopts)
		\? )
			error_str="$(gettext "Error")"
			error_txt="$(gettext "Unknown option")"
			printf '%s: %s: %s\n' "$MY_NAME" "$error_str" "${OPTARG}" >&2
			printf '%s --help\n' "${MY_NAME}" >&2
			exit 1
		;;
		### stop option processing
		-- )
			shift
			break
		;;
    esac
done

_verbose "Running internal command:" "${COMMAND}" "$@" >&2

_run_command "${COMMAND}" "$@" ; ret=$?
printf '\n'

# wait on user if in terminal
$terminal && read -pr 'Type Enter to close this terminal …'

# cleanup in case this is run by "sourcing" this file
set +u

# exit with commands return code
exit $ret

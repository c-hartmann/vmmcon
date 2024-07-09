#!/bin/bash

# vim: syntax=sh tabstop=4 softtabstop=0 expandtab shiftwidth=4 smarttab :

### ###########################################################################

### script: CreateVBoxVMfromISO.sh
### author: hartmann.christian@gmail.com, c-hartmann@github
### description: Creates a Virtual Machine from suitable ISO images (VirtualBox flavour)
### last update: 2022-01-20
### preferred places to live in:
### $HOME/.local/share/kservices5/
### $HOME/.local/share/kservices5/ServiceMenus

### ###########################################################################

# TODO rename script to CreateVMfromISOVBox.sh
# TODO create more functions to structure the code



### exit immediately if a command exits with a non-zero status
set -o errexit

### treat undefined vars as errors and break if found
set -o nounset

### get exit status from a pipeline
set -o pipefail

### avoid to fail if no template is installed
shopt -s nullglob

### allow case insensitive string comparisons
shopt -s nocasematch

### do not override existing files with output redirection (just in case we did something totaly wrong)
set -o noclobber

DEBUG=false
VERBOSE=true

$DEBUG && set -x

### ensure running in a controlled (language) environment
LANG=C

### me myself and i
MY_NAME=CreateVBoxVMfromISO
VERSION="0.9.0"

### my installation directory
### Kudos for that:
### https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
### (this also has a more complex solution for tricky environments)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ ! -d "$SCRIPT_DIR" ]]; then
	_error "not found SCRIPT_DIR: $SCRIPT_DIR"
else
	$VERBOSE && echo "running in $SCRIPT_DIR [1]"
fi

### same but different
CUR_PATH="$(dirname "$(readlink -m "$0")")"
$VERBOSE && echo "running in $CUR_PATH [2]"

VERSION=$(cat "$CUR_PATH/VERSION")
$VERBOSE && echo "version is: $VERSION"

### this is based on the idea of vm templates and this is where they live
TEMPLAT_DIR="$SCRIPT_DIR/${MY_NAME}.d"/templates.d

### _usage
### dead simple usage help on command line use
_usage ()
{
	cat << "    zzz" # NOTE the leading spaces must match with those in the zzz line

    Create VM from ISO (VBox version)

    Usage:  CreateVBoxVMfromISO [options] <iso-image-file>

    Options:
        -h               show this help
        -a               determine the template to use automagicaly
        -f               different approach to set ISO image file name
        -n               name the machine
        -p               power up the VM after creating
        -t <template>    a linux template to use
        -V               print the version and exit
        -v               turn on verbose mode
        -y               assume yes to all interactive questions

    zzz
} >&2



### initialize dialog type
declare gui
declare cli
declare cli_basic
declare cli_fancy
if [[ ! -t 0 ]]; then
	# running via service menu
	gui=true
	cli=false
else
	# running in command line
	gui=false
	cli=true
	if [[ -n "$(which dialog)" ]]; then
		# see: https://www.youtube.com/watch?v=A_QErp5C-z0
		# fancy command line mode
		cli_fancy=true
		cli_basic=false
	else
		# basic command line mode
		cli_basic=true
		cli_fancy=false
		echo -e "\e[32m\e[1mhint\e[0m: Consider to install '\e[1mdialog\e[0m' on your host to enable fance command line style for all dialogs herein"
	fi
fi



### NOTE: draft only, not used yet
### _dialog
### open either a kdialog when run through service menu (different environment?)
### or create a dialog on command line (any nice command line tool for this?)
_dialog ()
{
	dialog_type=$1
	text=$2
	shift 2

	title="$ME"

	# TODO: create variables from sample texts

	case $dialog_type in
		--message)
			$gui && kdialog --title "$title" --msgbox "<text>"
			:
			$cli_fancy && dialog --title "$title" --msgbox "<text>" 0 0 "<init>"
			return $?
		;;
		--question)
			$gui && kdialog --title "$title" --icon=question --yesno "<text>" --yes-label "<yes>" --no-label "<no>"
			:
			:
			return $?
		;;
		# TODO: do we need --question AND --yesno, or isn't that the same?
		--yesno)
			yes_label=${1:-"Yes"}
			$gui && kdialog --title "$title" --yesno "<text>" --yes-label "YesLabel" --no-label "NoLabel"
			$cli_basic && read ...
			$cli_fancy && dialog --title "$title" --clear --yes-label "YesLabel" --no-label "NoLabel" --yesno "<text>" 0 0
			return $?
		;;
		--input)
			init=$1
			temp=$(mktemp)
			$gui && input=$(kdialog --title "$title" --yes-label "Ok" --textinputbox "<text>" "<init>")
			$cli_basic && read ...
			$cli_fancy && dialog --title "$title" --clear --inputbox "<text>" 0 0 "<init>" 2> "$temp"
			cat "$temp"
			rm "$temp"
		;;
		--error)
			$gui && kdialog --title "$title" --error "Error: $*" --ok-label "So Sad"
			:
			:
		;;
	esac
}

### _error
### even more simple error handling
_error ()
{
	echo "Error: $*" >&2
	kdialog --error "Error: $*" --ok-label "So Sad"
	exit 1
}

### _canceled
_canceled ()
{
	echo "canceled" >&2
	exit 2
}

### _auto_template
_auto_template()
{
	local filename="$1"
	local matchtbl="$2"
	echo "getting template by: $filename" >&2
	ifs=';:,.'
	### for every first word in line match case insentive to image file name
	### on match use second word as template name
	### check for existence of found template (just in case we have done wrong in the list)
	### be case insensitive for this search
	shopt -s nocasematch
	# shellcheck disable=SC2034
	while IFS=$ifs read -r match template dump; do
		if [[ "$filename" =~ .*$match.* ]]; then
			echo "MATCHED BY: $match" >&2
			echo "TEMPLAT TO: $template" >&2
			break
		fi
	done < "$matchtbl"
	shopt -u nocasematch
	echo "$template"
	unset dump
}

### _get_host_memory_size
_get_host_memory_size ()
{
	local host_memory_size_kilobytes=$(grep MemTotal < /proc/meminfo | grep -o '[[:digit:]]*') # or: awk '{print $2}'
	echo $(( host_memory_size_kilobytes / 1024 ))
}



### where VBox generaly creates VMs 8and we store the disks in)
vbox_default_machine_folder=$(VBoxManage list systemproperties | sed -n 's/^Default machine folder: *//pi')
# shellcheck disable=SC2034
VBOX_VM_PATH=${vbox_default_machine_folder:-$HOME/.VirtualBox/VMs}
[[ -d "$VBOX_VM_PATH" ]] || _error "Couldn't determine default VM directory. All i have is: \"$VBOX_VM_PATH\"."

### where all the templates live. if you can't resists, you might create one for Window*
automagic_table="$SCRIPT_DIR/CreateVBoxVMfromISO.d/automagic.csv"
automagic_table_local="$SCRIPT_DIR/CreateVBoxVMfromISO.d/automagic.local.csv"

### desktop notifications will vanish after seconds
notification_timeout=4000

### a default VBox OS type to create (reset via template file)
vm_ostype=Linux_64

### these are internal defaults to determine the count of cpu core in the new VM
### both are available through the config files. by default the divider value is
### used to calculate the count for the vm from the physical host system.
### if vm_cpu_count is set to values greater than 0, this is used whatever the host
### might look like
vm_cpu_count=0
vm_cpu_count_divider=3

### set some defaults so we do not fail on using these later
auto=false
DEBUG=false
filepath=""
vm_name=""
pwr=false
typeset -l template=""
yes=false

### get template and file name from command line
tmpl=false
while getopts "acdf:hn:pt:vVy*" OPT; do
	echo opt="$OPT" >&2
	case $OPT in
		a)
			echo "running in automagic mode ..." >&2
			auto=true
		;;
		c)
			: # configure defaults: auto-power-up all, etc.
		;;
		d)
			echo "running in DEBUG mode ..." >&2
			DEBUG=true
		;;
		f)
			echo "f=$OPTARG" >&2
			filepath="$OPTARG"
			echo \$filepath=$filepath
		;;
		h)
			_usage
			exit 0
		;;
		n)
			echo "n=$OPTARG" >&2
			vm_name="$OPTARG"
		;;
		p)
			# power up after creating
			# shellcheck disable=SC2034
			pwr=true
		;;
		t)
			echo "t=$OPTARG"
			template="$OPTARG"
			typeset -l tmpl_cand
			# check valid template name by existence of template file (allowed to be empty)
			for dir in "$SCRIPT_DIR/${MY_NAME}.d"/templates.d/?*.conf; do
				tmpl_cand="${dir%.conf}"
				tmpl_cand="${tmpl_cand##*/}"
				if [[ "$tmpl_cand" =~ $template ]]; then
					tmpl=true
				fi
			done
			if [[ $tmpl != true ]]; then
				_error "template does not exists: \"$SCRIPT_DIR/${MY_NAME}.d/templates.d/${template}.conf\""
			fi
# 			[[ ! $template =~ arch|debian|ubuntu|fedora|linux|other ]] && {
# 				echo "Incorrect value provided for option template name"
# 				exit 1
# 			}
		;;
		V)
			echo "Version: $VERSION" >&2
			exit 0
		;;
		v)
			echo "running in VERBOSE mode ..." >&2
			VERBOSE=true
		;;
		y)
			echo "running in unattended mode ..." >&2
			yes=true
		;;
		### anything else is an usage error
		\?)
			echo "Error: unknown option: $OPTARG" >&2
			_usage
			exit 1
		;;
    esac
done
shift $((OPTIND -1))

### if filepath not set via option -f, use first argument instead
echo \$filepath=$filepath
if [[ -z "$filepath" ]]; then
	if [[ ! -v 1 ]]; then
		echo "\$1: $1" >&2
		filepath="$1"
		shift 1
	else
		echo "Error: no ISO image file name given" >&2
		_usage
		exit 1
	fi
fi

### still argumnets left over?
[[ $# -ge 1 ]] && _usage && exit 1

### check filepath on existence
if [[ ! -f "$filepath" ]]; then
	echo "Error: ISO image file name does not exist: $filepath" >&2
	_usage
	exit 1
fi

### use the filename for first dialog to suggest a VM name
filename=${filepath##*/}
echo \$filename=$filename

if [[ -z "$template" && $auto = true ]]; then
	if [[ -f "$automagic_table_local" ]]; then
		template=$(_auto_template "$filename" "$automagic_table_local")
	fi
	if [[ -z "$template" ]]; then
		template=$(_auto_template "$filename" "$automagic_table")
	fi
fi

# TODO remove this
echo "filepath: $filepath" >&2
echo "template: $template" >&2
if [[ -z "$template" ]]; then
	echo "Error: no template available. Give template with -t <template> or use -a to detect it automagicaly"
	exit 2
fi



### create a simple suggestion for the vm name from ISO file name
vm_name_suggest="${filename%.*}"
vm_name_suggest="${vm_name:-$vm_name_suggest}"
echo "suggested vm name: $vm_name_suggest" >&2

### inform the user*in"
if [[ $yes = true ]]; then
	:
else
	if ! kdialog --title "AddAsVBoxMedia" --icon=question --yesno "Create Virtual Machine from \"$filename\"?" --yes-label "Create" --no-label "Cancel"; then
		_canceled
	fi
fi

### get a name for the new virtual machine
if [[ $yes = true ]]; then
	vm_name="$vm_name_suggest"
else
	if ! vm_name=$(kdialog --title "AddAsVBoxMedia" --icon=question --inputbox "Name of virtual machine to create:" "$vm_name_suggest"); then
		_canceled
	fi
fi
echo "creating \"$vm_name\"..." >&2

### check if name is already in use (exit on true)
VBoxManage list vms | cut -d '"' -f 2 | grep --fixed-strings --line-regexp "$vm_name" && _error "VM already exists: \"$vm_name\""



### set memory default values
vm_memory_size=0
vm_memory_size_fallback=4096
vm_memory_size_divider=4

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
vm_nested_virt="off" # 'on' enables PAE as well

### VBox recommends to use VMSVG graphics controller, so we do that
### VMSVGA: Use this graphics controller to emulate a VMware SVGA graphics device.
### This is the *default* graphics controller for Linux guests.
vm_gfx_controller="vmsvga" # default: "vboxvga", other: vmsvga

### EFI screen resolutions (https://www.virtualbox.org/manual/ch03.html#efi)
vm_efi_gfx_resolution="1920x1200" # WUXGA
vm_efi_gfx_resolution="1280x1024" # SXGA
vm_efi_gfx_resolution="1280x800"  # WXGA

### most newer linux make use of 3D accelaration feature if present
### so we do (via teh BASE.conf although it defaults to off and requires
### guest additions being installed
vm_gfx_accelerate3d="off"

### support neted paging on vt enabled hosts only
vm_nestedpaging="off"
vm_paravirtprovider="none"

### these are the defaults for Linux guests
# "ps2kbd" for keyboard?
# see: vboxmanage showvminfo --machinereadable $VM | grep -E 'hidkeyboard|hidpointing'
vm_hid_pointing="usbtablet"
vm_hid_keyboard="ps2"

### execute the config file now as this might impact the calculation of cpu core
CONF="$SCRIPT_DIR/${MY_NAME}.conf"
if [[ -f "$CONF" ]]; then
	echo "running $CONF" >&2
	# shellcheck disable=SC1090
	. "$CONF"
fi

### things to determine by parent host (a third of actual cpu cores is
### acceptabel and our default on computation)
host_cpu_count=$(grep -Ec '(vmx|svm)' /proc/cpuinfo) # if no output, host either so not support virtualization or it isn't enabled. bummer
if (( vm_cpu_count == 0 )); then
	echo -n "computing count of virtual cpus..." >&2
	if (( host_cpu_count > 0 )); then
		vm_nestedpaging="on" # defaults to on (i.e. using host cpu vt technology)
		vm_paravirtprovider="kvm" # kvm is default for Linux guests
		### compute a reasonable count for the count of guest cpu cores
		vm_cpu_count=$(( host_cpu_count / vm_cpu_count_divider ))
	else
		vm_cpu_count=1
	fi
	echo -e "\b\b\b to: $vm_cpu_count" >&2
else
	echo "using fixed count of virtual cpus: $vm_cpu_count" >&2
fi

host_memory_size=$(_get_host_memory_size)
if (( vm_memory_size == 0 )); then
	echo -n "computing amount of virtual memory..." >&2
	if (( host_memory_size > 0 )); then
		vm_memory_size=$(( host_memory_size / vm_memory_size_divider ))
	else
		vm_memory_size=$vm_memory_size_fallback
	fi
	echo -e "\b\b\b to: $vm_memory_size" >&2
else
	echo "using fixed amount of virtual memory: $vm_memory_size" >&2
fi



### level of USB support at host
vm_usb="on"      # USB-1.1, default: "off"
vm_usbehci="on"  # USB-2.0, default: "off" # ? TODO: onl if host supports it?
vm_usbxhci="off" # USB-3.0, default: "off" # ? TODO: onl if host supports it?

### audio
vm_audioout="on"
vm_audioin="off"
vm_audiocontroller="ac97"
vm_audiocodec="ad1980" # default in gui mode

### run template config file, if it is there, always run BASE
for conf in "$TEMPLAT_DIR/BASE.conf" \
	"$TEMPLAT_DIR/${template}.conf"; do
	if [[ -f "$conf" ]]; then
		echo "running $conf" >&2
		# shellcheck disable=SC1090
		. "$conf"
	else
		_error "template does not exist: \"$conf\"" >&2
	fi
done



### create vm
notify-send --app-name="Create VBox VM from ISO" --icon=virtualbox --expire-time=$notification_timeout "Creating new VM ..."

echo VBoxManage createvm --name "$vm_name" --ostype $vm_ostype --register >&2
     VBoxManage createvm --name "$vm_name" --ostype $vm_ostype --register



### main and graphcis memory
echo VBoxManage modifyvm "$vm_name" --memory $vm_memory_size >&2
     VBoxManage modifyvm "$vm_name" --memory $vm_memory_size
echo VBoxManage modifyvm "$vm_name" --vram $vm_vram_size >&2
     VBoxManage modifyvm "$vm_name" --vram $vm_vram_size

### cpu
echo VBoxManage modifyvm "$vm_name" --cpus "$vm_cpu_count" >&2
     VBoxManage modifyvm "$vm_name" --cpus "$vm_cpu_count"
echo VBoxManage modifyvm "$vm_name" --pae "$vm_pae" >&2
     VBoxManage modifyvm "$vm_name" --pae "$vm_pae"
echo VBoxManage modifyvm "$vm_name" --nested-hw-virt "$vm_nested_virt" >&2
     VBoxManage modifyvm "$vm_name" --nested-hw-virt "$vm_nested_virt"

### cpu acceleration
echo VBoxManage modifyvm "$vm_name" --paravirtprovider "$vm_paravirtprovider" >&2
     VBoxManage modifyvm "$vm_name" --paravirtprovider "$vm_paravirtprovider"
echo VBoxManage modifyvm "$vm_name" --nestedpaging "$vm_nestedpaging" >&2
     VBoxManage modifyvm "$vm_name" --nestedpaging "$vm_nestedpaging"

### graphcis controller
echo VBoxManage modifyvm "$vm_name" --graphicscontroller "$vm_gfx_controller" >&2
     VBoxManage modifyvm "$vm_name" --graphicscontroller "$vm_gfx_controller"

### 3D acceleration (not applying until guest additions will be installed)
echo VBoxManage modifyvm "$vm_name" --accelerate3d "$vm_gfx_accelerate3d" >&2
     VBoxManage modifyvm "$vm_name" --accelerate3d "$vm_gfx_accelerate3d"

### usb capabilities
echo VBoxManage modifyvm "$vm_name" --usb "$vm_usb" >&2
     VBoxManage modifyvm "$vm_name" --usb "$vm_usb"
echo VBoxManage modifyvm "$vm_name" --usbehci "$vm_usbehci" >&2
     VBoxManage modifyvm "$vm_name" --usbehci "$vm_usbehci"
echo VBoxManage modifyvm "$vm_name" --usbxhci "$vm_usbxhci" >&2
     VBoxManage modifyvm "$vm_name" --usbxhci "$vm_usbxhci"

### motherboard
echo VBoxManage modifyvm "$vm_name" --acpi "$vm_acpi" >&2
     VBoxManage modifyvm "$vm_name" --acpi "$vm_acpi"
echo VBoxManage modifyvm "$vm_name" --ioapic "$vm_ioapic" >&2
     VBoxManage modifyvm "$vm_name" --ioapic "$vm_ioapic"
echo VBoxManage modifyvm "$vm_name" --firmware "$vm_firmware" >&2
     VBoxManage modifyvm "$vm_name" --firmware "$vm_firmware"
echo VBoxManage modifyvm "$vm_name" --chipset "$vm_chipset" >&2
     VBoxManage modifyvm "$vm_name" --chipset "$vm_chipset"
echo VBoxManage modifyvm "$vm_name" --rtcuseutc "$vm_rtcuseutc" >&2
     VBoxManage modifyvm "$vm_name" --rtcuseutc "$vm_rtcuseutc"
if [[ "$vm_firmware" =~ efi.* ]]; then
	echo VBoxManage setextradata "$vm_name" VBoxInternal2/EfiGraphicsResolution $vm_efi_gfx_resolution
	     VBoxManage setextradata "$vm_name" VBoxInternal2/EfiGraphicsResolution $vm_efi_gfx_resolution
fi

### audio
echo VBoxManage modifyvm "$vm_name" --audioout "$vm_audioout" >&2
     VBoxManage modifyvm "$vm_name" --audioout "$vm_audioout"
echo VBoxManage modifyvm "$vm_name" --audioin "$vm_audioin" >&2
     VBoxManage modifyvm "$vm_name" --audioin "$vm_audioin"
# --audiocontroller ac97|hda|sb16: Specifies the audio controller to be used with the VM.
# --audiocodec stac9700|ad1980|stac9221|sb16: Specifies the audio codec to be used with the VM.
echo VBoxManage modifyvm "$vm_name" --audiocontroller "$vm_audiocontroller" >&2
     VBoxManage modifyvm "$vm_name" --audiocontroller "$vm_audiocontroller"
echo VBoxManage modifyvm "$vm_name" --audiocodec "$vm_audiocodec" >&2
     VBoxManage modifyvm "$vm_name" --audiocodec "$vm_audiocodec"


# TODO pointer device type (usb, ps/2 (default))
# --keyboard <ps2|usb>
# --mouse <ps2|usb|usbtablet|usbmultitouch>
echo VBoxManage modifyvm "$vm_name" --mouse "$vm_hid_pointing" >&2
     VBoxManage modifyvm "$vm_name" --mouse "$vm_hid_pointing"
echo VBoxManage modifyvm "$vm_name" --keyboard "$vm_hid_keyboard" >&2
     VBoxManage modifyvm "$vm_name" --keyboard "$vm_hid_keyboard"

# VBoxManage modifyvm "$vm_name" --description <desc>: Changes the VM's description, which is a way to record details about the VM in a way which is meaningful for the user
echo VBoxManage modifyvm "$vm_name" --description "this VM has been created by:  CreateVMfromISOVBox" >&2
     VBoxManage modifyvm "$vm_name" --description "this VM has been created by:  CreateVMfromISOVBox"



# more nice stuff that could be done..

# VBoxManage modifyvm "$vm_name" --iconfile <filename>: Specifies the absolute path on the host file system for the Oracle VM VirtualBox icon to be displayed in the VM
# we have huge icons and some bit smaller in $SCRIPT_DIR/CreateVBoxVMfromISO.d/distro_icons.d/(512|128)

# TODO cpu limitation? to what percentage? 80?

VBoxManage storagectl "$vm_name" \
	--name "IDE" \
	--add ide

### mimik the behaviour of the GUI as good as we can
### --port 0 --device 0 = Primary Master
### --port 0 --device 1 = Primary Slave
### --port 1 --device 0 = Secondary Master
### --port 1 --device 1 = Secondary Slave
VBoxManage storageattach "$vm_name" \
	--storagectl "IDE" \
	--port 1 \
	--device 0 \
	--type dvddrive \
	--medium "$filepath"

### add SATA controller, add disk and attach disk to SATA
# TODO controller types are available
# shellcheck disable=SC2034
vm_sata_controller="IntelAHCI"
VBoxManage storagectl "$vm_name" \
	--name "SATA" \
	--add sata \
	--controller "$vm_sata_controller" \
	--portcount 1 \
	--bootable on

# TODO switch disk type to vmdk? the upcoming qemu flavour of this script could use that one out of the box
declare -l _vm_disk_type="$vm_disk_type"
declare -u _vm_disk_format="$vm_disk_type"
declare -A _vm_disk_variants
_vm_disk_variants[dynamic]="Standard"
_vm_disk_variants[fixed]="Fixed"
declare -l _vm_disk_alloc="$vm_disk_alloc"
_vm_disk_variant=${_vm_disk_variants[$_vm_disk_alloc]}
### create hard disk if not disabled (disk count = 0)
if (( vm_disk_count > 0 )); then
	VM_DISK_DIR="$(dirname "$(VBoxManage showvminfo "$vm_name" | sed -n 's/^Config file: *//pi')")"
	VM_DISK_DIR=${VM_DISK_DIR:-$VBOX_VM_PATH/$vm_name}
	VBoxManage createmedium "disk" \
		--filename "$VM_DISK_DIR/$vm_name.$_vm_disk_type" \
		--format "$_vm_disk_format" \
		--variant "$_vm_disk_variant" \
		--size $((vm_disk_size*1024))
	VBoxManage storageattach "$vm_name" \
		--storagectl "SATA" \
		--port 0 \
		--device 0 \
		--type hdd \
		--medium "$VM_DISK_DIR/$vm_name.$vm_disk_type"
fi

### desktop 'notification' on success and eventualy power the box up
if ! $pwr ; then
	if kdialog --title "${MY_NAME}" --icon virtualbox --yesno "New VM added:\n\"$vm_name\".\nPower up now?" --yes-label "Power Up" --no-label "Not Yet"; then
		pwr=true
	fi
fi
if $pwr ; then
	# run vbox, run
	VBoxManage startvm "$vm_name" --type gui # or headless?
else
	notify-send --app-name="${MY_NAME}" --icon=virtualbox --expire-time=$notification_timeout "New VM not started"
fi

# TODO find a real notification with two buttons such as kdialog above
#notify-send --app-name="Create VBox VM from ISO" --icon=virtualbox --expire-time=$notification_timeout "VM added: \"$vm_name\""

# gdbus call --session \
#     --dest=org.freedesktop.Notifications \
#     --object-path=/org/freedesktop/Notifications \
#     --method=org.freedesktop.Notifications.Notify \
#     "" 0 "" 'Create VBox VM from ISO' "Virtual Machine added:<br>\"<b>$vm_name</b>\" \
#     '[]' '{"urgency": <1>}' 5000
# notification with "Start Now button? A Notification might be the wrong place to start something up

# https://askubuntu.com/questions/726839/how-to-send-kde5-desktop-notification-from-a-bash-script
# qdbus org.kde.knotify /Notify event "event" 'app' "(" ")" 'title' 'text' 'pixmap' '' 5 0

# /usr/share/dbus-1/
# /usr/share/dbus-1/services/
# /usr/share/dbus-1/interfaces/

# in case this is run by "sourcing" this file
set +u

# TODO treat this as a "src" file and create a command (without the extension) by running make or similar
#      i might try so separate my comments from comments that should stay in the file .. ### for those?

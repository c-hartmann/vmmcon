# share/vmmcon/vmms/vbox/functions.sh
# this is a library:
# https://google.github.io/styleguide/shellguide.html

function _set_vbox_manage_command()
{
	### tradionaly there is VBoxManage, but looks like the
	### project is moving to lowercased command names, as there
	### are more of these than in traditional mixed spelling
	#ä TODO try to use mixed case, if lower fails
# 	_vboxmanage_cmd="$(type -p VBoxManage)"
# 	_vboxmanage_cmd="$(type -p vboxmanage)"
	### in fact both of these are just symbolic links to /usr/bin/VBox,
	### but there are move of these links and VBox probably evaluates
	### $0 before doing anything. And VBox actualy is a shell script,
	### that internaly calls /usr/lib/virtualbox/VBoxManage for both
	### names above.
	_vboxmanage_cmd_avails=($(type -p VBoxManage vboxmanage VBox))
	_vboxmanage_cmd="${_vboxmanage_cmd_avails[0]}"
}
_set_vbox_manage_command



# _vbox_manage - wrapper on VBoxManage that respects dry mode
function _vbox_manage()
{
	local quiet=false
	[[ $1 == "--quiet" ]] && quiet=true && shift 1
	arg_count_control=$1 && shift 1
	$VERBOSE && printf 'running external command: %s\n' "$_vboxmanage_cmd" "$*" >&2 # TODO: _verbose()?
	[[ $arg_count_control = $# ]] || _error_exit "actual argument count ($#) does not match given argument count ($arg_count_control)"
# 	$quiet || printf 'running external command: %s\n' "$_vboxmanage_cmd" "$*" >&2
	# TODO if not silent command
# 	declare _silent_commands=( "list" "showvminfo" )
# 	if [[ "$1" != "list" ]]; then
# 		printf '%s\n' "VBoxManage $*" >&2
# 	fi
	$dry || $_vboxmanage_cmd "$@"
}



function vmms::clone_vm() # "$VM"
{
	local _vm="$1"
 	local _vm_clone="$2"
	local _cloned=1

	### no clone name ?
	if [[ -z $_vm_clone ]]; then
		_vm_clone="${_vm}"
		if [[ -n "$STAMP" ]]; then
			_vm_clone="${_vm_clone} (${STAMP})"
		else
			_vm_clone="${_vm_clone} (${TODAY})"
		fi
	fi

	_verbose "_vm_clone=${_vm_clone}" >&2

	### get confirmation for name for the cloned virtual machine
	if [[ $yes = true ]]; then
		_vm_clone="${_vm_clone}"
	else
		if ! _vm_clone=$(_get_vm_name "${_vm_clone}"); then
			_canceled_exit
		fi
	fi

	### run dolly run (now *with* snapshots (mode=all))
	_vbox_manage 6 clonevm "${_vm}" --name="${_vm_clone}" --mode="machine" --mode=all --register && _cloned=0

	# TODO: we might have a problem with *not* creating a new
	#       MAC address for the network adapter (VB *does* this)

	# NOTE: --options=KeepAllMACs
	#       the default behavior is to reinitialize the MAC addresses of each virtual network card
	#       THIS SEEMS TO BE NOT TRUE!
	# NOTE: it *is* true! a new mac address *is* created but not effective until new or re-boot

	# trying to fix the *not* created new mac address...
# 	_vbox_manage 2 --macaddress1 auto

	_vbox_manage 4 modifyvm "$_vm" --description "this VM has been cloned from ${_vm} by $ME at $TODAY"

	return $_cloned
}
function create_random_tcp_port_num()
{
	min=1028
	max=32766
	R1=$(($RANDOM%($max-$min+1)+$min))
	R2=$(($RANDOM%($max-$min+1)+$min))
	echo $((R1+R2))
}
function vmms::set_ssh_port()
{
	local _vm="$1"
# 	local _port="$2"
	_vm_tcp_ssh_port=$(create_random_tcp_port_num)
	_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-port' "$_vm_tcp_ssh_port"
}
function vmms::get_ssh_port()
{
	local _vm="$1"
	_vbox_manage 3 getextradata "$_vm" 'vmmcon-tcp-ssh-port' | sed 's/[^0-9]//g'
}
function vmms::set_ssh_username()
{
	local _vm="$1"
# 	local _user="$2"
	_vm_tcp_ssh_username=${vm_tcp_ssh_username:-$LOGNAME}
	_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-username' "$_vm_tcp_ssh_username"
}
function vmms::get_ssh_username()
{
	local _vm="$1"
	local _vm_tcp_ssh_username=$(_vbox_manage 3 getextradata "$_vm" 'vmmcon-tcp-ssh-username' 2>/dev/null | grep 'Value:' | sed 's/Value: //')
	printf '%s' "${_vm_tcp_ssh_username:-$LOGNAME}"
}
function vmms::set_ssh_port_forwarding_rule()
{
	local _vm="$1"
	_vm_nnet_adapter=1
	_vm_pf_rulename="VMMCON-SSH"
# 	_host_ip_address="127.0.0.1" # may be empty !? see: https://superuser.com/questions/901422/virtualbox-command-line-setting-up-port-forwarding
	_host_ip_address='' # see: https://www.virtualbox.org/manual/ch06.html#natforward
	_vm_tcp_ssh_port=$(vmms::get_ssh_port "$_vm")
	_vm_ip_address=''
	_vbox_manage 4 modifyvm "$_vm" --natpf${_vm_nnet_adapter} "${_vm_pf_rulename},tcp,${_host_ip_address},${_vm_tcp_ssh_port},${_vm_ip_address},22"
}
function vmms::create_vm_ssh_login()
{
	local _vm="$1"
	_created=1
	_existing_ssh_port=$(vmms::get_ssh_port "$_vm")
	if [[ -n "$_existing_ssh_port" ]]; then
		_error_exit "ssh port already exists: $_existing_ssh_port"
	else
# 		_vm_pf_rulename="VMMCON-SSH"
# 		_vbox_manage 4 modifyvm "$_vm" --natpf${_vm_nnet_adapter} "${_vm_pf_rulename},tcp,${_host_ip_address},${_vm_tcp_ssh_port},${_vm_ip_address},22"
# 		_vm_tcp_ssh_port=$(create_random_tcp_port_num)
# 		_vm_tcp_ssh_username=${vm_tcp_ssh_username:-$LOGNAME}
# 		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-port' ${_vm_tcp_ssh_port}
		vmms::set_ssh_port "$_vm"
		vmms::set_ssh_port_forwarding_rule "$_vm"
# 		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-usernam' ${_vm_tcp_ssh_username}
		vmms::set_ssh_username "$_vm"
		_created=0
	fi
}
function vmms::get_vm_network_mode()
{
	# TODO: support anything else than Bridged and NAT?
	local _vm="$1"
	VBoxManage showvminfo "$_vm" | grep -oE 'Bridged|NAT' 
}
function vmms::get_vm_bridged_ip_addr()
{
	local _vm="$1"
# 	typeset -l arp="$(_vbox_manage 2 showvminfo "$_vm" \
	typeset -l arp="$(VBoxManage showvminfo "$_vm" \
	  | grep -oe 'MAC: [^,]*,' \
	  | awk '{print $2}' \
	  | grep -oe '[0-9A-F]*' \
	  | sed 's/\(..\)/\0\:/g' \
	  | sed -e 's/:$//')"
	arp -a | grep "$arp" | grep -o '(.*)' | sed 's/[()]//g'
}
function vmms::create_vm_serial_port()
{
	local _vm="$1"
	_created=1
	_existing_ssh_port=$(vmms::get_ssh_port "$_vm")
	if [[ -n "$_existing_ssh_port" ]]; then
		_error_exit "ssh port already exists: $_existing_ssh_port"
	else
# 		_vm_pf_rulename="VMMCON-SSH"
:
# 		_vbox_manage 4 modifyvm "$_vm" --natpf${_vm_nnet_adapter} "${_vm_pf_rulename},tcp,${_host_ip_address},${_vm_tcp_ssh_port},${_vm_ip_address},22"

# 		_vm_tcp_ssh_port=$(create_random_tcp_port_num)
# 		_vm_tcp_ssh_username=${vm_tcp_ssh_username:-$LOGNAME}
# 		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-port' ${_vm_tcp_ssh_port}
		vmms::set_ssh_port "$_vm"
		vmms::set_ssh_port_forwarding_rule "$_vm"
# 		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-usernam' ${_vm_tcp_ssh_username}
		vmms::set_ssh_username "$_vm"
		_created=0
	fi
}
function vmms::_create_vm()
{
	# TODO https://docs.oracle.com/en/virtualization/virtualbox/6.0/admin/security-recommendations.html

	local _vm="$1"

	_created=1

	_vbox_manage 6 createvm --name "$_vm" --ostype "$vm_ostype" --register

	### main and graphcis memory
	_vbox_manage 4 modifyvm "$_vm" --memory $vm_memory_size
	_vbox_manage 4 modifyvm "$_vm" --vram $vm_vram_size

	### motherboard
	_vbox_manage 4 modifyvm "$_vm" --acpi "$vm_acpi"
	_vbox_manage 4 modifyvm "$_vm" --ioapic "$vm_ioapic"
	_vbox_manage 4 modifyvm "$_vm" --chipset "$vm_chipset"
	_vbox_manage 4 modifyvm "$_vm" --rtcuseutc "$vm_rtcuseutc"
	_vbox_manage 4 modifyvm "$_vm" --firmware "$vm_firmware"

	if [[ "$vm_firmware" =~ efi.* ]]; then
		_vbox_manage 4 setextradata "$_vm" "VBoxInternal2/EfiGraphicsResolution" "$vm_efi_gfx_resolution"
	fi

	### cpu count and virtualization
	_vbox_manage 4 modifyvm "$_vm" --cpus $vm_cpu_count
	_vbox_manage 4 modifyvm "$_vm" --pae "$vm_pae"
	_vbox_manage 4 modifyvm "$_vm" --nested-hw-virt "$vm_nested_virt"

	### cpu acceleration
	_vbox_manage 4 modifyvm "$_vm" --paravirtprovider "$vbox_vm_paravirtprovider"
	_vbox_manage 4 modifyvm "$_vm" --nestedpaging "$vm_nestedpaging"
	_vbox_manage 4 modifyvm "$_vm" --large-pages "$vm_largepages"

	### graphcis controller
	_vbox_manage 4 modifyvm "$_vm" --graphicscontroller "$vm_gfx_controller"

	### 3D acceleration (not functional without installed guest additions) (maybe: also not functional without installation of driver for hosts graphics in guest)
	_vbox_manage 4 modifyvm "$_vm" --accelerate3d "$vm_gfx_accelerate3d"

	### usb capabilities
	_vbox_manage 4 modifyvm "$_vm" --usb "$vm_usb"
	_vbox_manage 4 modifyvm "$_vm" --usbehci "$vm_usb_ehci"
	_vbox_manage 4 modifyvm "$_vm" --usbxhci "$vm_usb_xhci"

	### audio
	# TODO: some things are depricated now. see: https://www.virtualbox.org/wiki/Changelog-7.0
	_vbox_manage 4 modifyvm "$_vm" --audioout "$vm_audioout"
	_vbox_manage 4 modifyvm "$_vm" --audioin "$vm_audioin"
	# --audiocontroller ac97|hda|sb16: Specifies the audio controller to be used with the VM.
	# --audiocodec stac9700|ad1980|stac9221|sb16: Specifies the audio codec to be used with the VM.
	_vbox_manage 4 modifyvm "$_vm" --audiocontroller "$vm_audiocontroller"
	_vbox_manage 4 modifyvm "$_vm" --audiocodec "$vm_audiocodec"

	# TODO pointer device type (usb, ps/2 (default))
	# --keyboard <ps2|usb>
	# --mouse <ps2|usb|usbtablet|usbmultitouch>
	_vbox_manage 4 modifyvm "$_vm" --mouse "$vm_hid_pointing"
	_vbox_manage 4 modifyvm "$_vm" --keyboard "$vm_hid_keyboard"

	# VBoxManage modifyvm "$_vm" --description <desc>: Changes the VM's description, which is a way to record details about the VM in a way which is meaningful for the user
	_vbox_manage 4 modifyvm "$_vm" --description "this VM has been created by ${ME} at ${TODAY}"
	
	# TODO enabling port forwarding rules should be controlled via the rc file
	# Add port forwarding rule for ssh remote login
	# WARNING the command option name has been modified throughout the versions: from '--natpf1' (until vbox 6.x) to 'natpf1' (controlvm) to '--nat-pf1' (by vbox 7.0, but --natpf1 still works)
	# see also: https://www.virtualbox.org/ticket/10122
	# for option name see: https://docs.oracle.com/en/virtualization/virtualbox/7.0/user/networkingdetails.html#natforward
	# > the vm ip address is asigned by the vbox builtin DHCP server. so it may vary
	# TODO WARNING with multiple running vms, these vms can not share the same forwarded port 2222
	# this might be an approach...
	# $ UUID="b42669e1-1a06-4cc1-aecc-47af4f9854f6"
	# $ echo $UUID | sed 's/[a-z-]//g'
	# 4266911064147498546 # TODO is there an upper limit for local ports?

	_vm_nnet_adapter=1
	_vm_ip_address=''
	_host_ip_address=''

	
	typeset -l _vm_network_mode="${vm_network_mode:-'nat'}"
	
	if [[ $_vm_network_mode == 'nat' ]]; then
	
# 		vm_pf_rulename="VMMCON-SSH"
# 		_vbox_manage 4 modifyvm "$_vm" --natpf${_vm_nnet_adapter} "${vm_pf_rulename},tcp,${_host_ip_address},${_vm_tcp_ssh_port},${_vm_ip_address},22"
# 		_vm_tcp_ssh_port=$(create_random_tcp_port_num)
# 		_vm_tcp_ssh_username=${vm_tcp_ssh_username:-$LOGNAME}
# 		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-port' ${_vm_tcp_ssh_port}
# 		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-ssh-username' ${_vm_tcp_ssh_username}
# 		vmms::set_ssh_port ${_vm_tcp_ssh_port}
		vmms::create_vm_ssh_login "$_vm"

		# Another one for HTTP(s) servers?
		vm_pf_rulename="VMMCON-HTTP"
		_vm_tcp_http_port=$(create_random_tcp_port_num)
		_vbox_manage 4 modifyvm "$_vm" --natpf${_vm_nnet_adapter} "${vm_pf_rulename},tcp,${_host_ip_address},${_vm_tcp_http_port},${_vm_ip_address},80"
		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-http-port' ${_vm_tcp_http_port}

		vm_pf_rulename="VMMCON-HTTPS"
		_vm_tcp_https_port=$(create_random_tcp_port_num)
		_vbox_manage 4 modifyvm "$_vm" --natpf${_vm_nnet_adapter} "${vm_pf_rulename},tcp,${_host_ip_address},${_vm_tcp_https_port},${_vm_ip_address},443"
		_vbox_manage 4 setextradata "$_vm" 'vmmcon-tcp-https-port' ${_vm_tcp_https_port}

	fi

	if [[ $_vm_network_mode == 'bridged' ]]; then
		_vbox_manage 3 modifyvm "$_vm" --nic${_vm_nnet_adapter}=bridged
	fi

	
	
	# only the sky is the limit
	# TODO ? is this functional without vbox guest additions.
	#        Likely not, but some have this preinstalled even on install ISOs
	# TODO ? does this makes sence for Linux guests at all
	_vbox_manage 4 setextradata global GUI/MaxGuestResolution any
	_i=1
	_extradata=''
	for _extradata in ${vm_gfx_controller_resolutions[@]} ; do
		_vbox_manage 4 setextradata "$_vm" CustomVideoMode$((_i++)) "$_extradata"
	done
	if [[ -n "$_extradata" ]] ; then
		echo _vbox_manage 6 controlvm "$_vm" setvideomodehint $(printf '%s' $_extradata | tr 'x' ' ')
	fi

	# more nice stuff that could be done...

	# VBoxManage modifyvm "$_vm" --iconfile <filename>: Specifies the absolute path on the host file system for the Oracle VM VirtualBox icon to be displayed in the VM
	# we have huge icons and some bit smaller in $SCRIPT_DIR/CreateVBoxVMfromISO.d/distro_icons.d/(512|128)

# 	### mimik the behaviour of the GUI as good as we can
# 	### --port 0 --device 0 = Primary Master
# 	### --port 0 --device 1 = Primary Slave
# 	### --port 1 --device 0 = Secondary Master
# 	### --port 1 --device 1 = Secondary Slave
# 	_vbox_manage 6 storagectl  "$_vm" \
# 		--name "IDE" \
# 		--add ide
# 	_vbox_manage 12 storageattach  "$_vm" \
# 		--storagectl "IDE" \
# 		--port 1 \
# 		--device 0 \
# 		--type dvddrive \
# 		--medium "$filepath"

# 	### add SATA controller, add disk and attach disk to SATA
# 	# TODO controller types are available
# 	# shellcheck disable=SC2034
# 	vm_disk_controller="${vm_disk_controller:="IntelAHCI"}"
# 	vm_disk_controller_name="${vm_disk_controller_name:="SATA"}"
# 	_vbox_manage 12 storagectl  "$_vm" \
# 		--name "$vm_disk_controller_name" \
# 		--add sata \
# 		--controller "$vm_disk_controller" \
# 		--portcount 1 \
# 		--bootable on
# 
# 	# TODO switch disk type to vmdk? the upcoming qemu flavour of this script could use that one out of the box
# 	declare -l _vm_disk_type="$vm_disk_type"
# 	declare -u _vm_disk_format="$vm_disk_type" # TODO: correct? see ~20 lines below. seems to be correct
# 	declare -A _vm_disk_variants
# 	### translate internal key words to vbox command options
# 	_vm_disk_variants[dynamic]="Standard"
# 	_vm_disk_variants[fixed]="Fixed"
# 	### ensure array keys to be lower cased
# 	declare -l _vm_disk_alloc="${vm_disk_alloc}" # other way to lower the case: _vm_disk_alloc="${vm_disk_alloc,,}"
# 	_vm_disk_variant=${_vm_disk_variants[$_vm_disk_alloc]}
# 	printf "creating $vm_disk_count disk(s) of $vm_disk_size GB type '$vm_disk_type'\n" >&2
# 	### create hard disk if not disabled (disk count == 0)
# 	if (( vm_disk_count > 0 )); then
# 		VM_DISK_DIR="$(dirname "$(_vbox_manage 2 showvminfo "$_vm" 2>/dev/null | sed -n 's/^Config file: *//pi')" | sed -n 's/^.$//i')"
# 		VM_DISK_DIR="${VM_DISK_DIR:-$VBOX_VM_PATH/$vm_name}"
# 		# TODO disk creation is a critical process, that might fail! on error user shall be informed!
# 		# one of the common errors: VBox GUI does bot delete all files, although told so! (if file still
# 		# exists with the name we create automatically, the createmedium will fail!
# 		_vbox_manage 10 createmedium "disk" \
# 			--filename "$VM_DISK_DIR/$vm_name.$_vm_disk_type" \
# 			--format "$_vm_disk_format" \
# 			--variant "$_vm_disk_variant" \
# 			--size $((vm_disk_size*1024))
# 		_vbox_manage 12 storageattach  "$_vm" \
# 			--storagectl "$vm_disk_controller_name" \
# 			--port 0 \
# 			--device 0 \
# 			--type hdd \
# 			--medium "$VM_DISK_DIR/$vm_name.$vm_disk_type"
# 	fi

	_created=0
	return $_created
}



function vmms::_create_vdi_image_from_raw_image()
{
	local _vm="$1"
	local _fp="$2"
	declare -l _vm_disk_type="$vm_disk_type"
	declare -u _vm_disk_format="$vm_disk_type" # TODO: correct? see ~20 lines below. seems to be correct
	declare -A _vm_disk_variants
	### translate internal key words to vbox command options
	_vm_disk_variants[dynamic]="Standard"
	_vm_disk_variants[fixed]="Fixed"
	### ensure array keys to be lower cased
	declare -l _vm_disk_alloc="${vm_disk_alloc}" # other way to lower the case: _vm_disk_alloc="${vm_disk_alloc,,}"
	VM_DISK_DIR="$(dirname "$(_vbox_manage 2 showvminfo "$_vm" 2>/dev/null | sed -n 's/^Config file: *//pi')" | sed -n 's/^.$//i')"
	VM_DISK_DIR="${VM_DISK_DIR:-$VBOX_VM_PATH/$_vm}"
	_vm_disk_variant=${_vm_disk_variants[$_vm_disk_alloc]}
	_vbox_manage 7 convertfromraw "$_fp" "$VM_DISK_DIR/$_vm.$vm_disk_type" \
			--format "$_vm_disk_format" \
			--variant "$_vm_disk_variant"
}

function vmms::_add_storage_controller_sata()
{
	### add SATA controller, add disk and attach disk to SATA
	# TODO controller types are available
	vm_disk_controller="${vm_disk_controller:="IntelAHCI"}"
	vm_disk_controller_name="${vm_disk_controller_name:="SATA"}"
	_vbox_manage 12 storagectl  "$_vm" \
		--name "$vm_disk_controller_name" \
		--add sata \
		--controller "$vm_disk_controller" \
		--portcount 1 \
		--bootable on
	# TODO error check
	printf "%s" "$vm_disk_controller_name"
}
function vmms::_create_disk()
{
	local _vm="$1"
	# TODO switch disk type to vmdk? the upcoming qemu flavour of this script could use that one out of the box
	declare -l _vm_disk_type="$vm_disk_type"
	declare -u _vm_disk_format="$vm_disk_type" # TODO: correct? see ~20 lines below. seems to be correct
	declare -A _vm_disk_variants
	### translate internal key words to vbox command options
	_vm_disk_variants[dynamic]="Standard"
	_vm_disk_variants[fixed]="Fixed"
	### ensure array keys to be lower cased
	declare -l _vm_disk_alloc="${vm_disk_alloc}" # other way to lower the case: _vm_disk_alloc="${vm_disk_alloc,,}"
	_vm_disk_variant=${_vm_disk_variants[$_vm_disk_alloc]}
	# TODO disk creation is a critical process, that might fail! on error user shall be informed!
	# one of the common errors: VBox GUI does bot delete all files, although told so! (if file still
	# exists with the name we create automatically, the createmedium will fail!
	VM_DISK_DIR="$(dirname "$(_vbox_manage 2 showvminfo "$_vm" 2>/dev/null | sed -n 's/^Config file: *//pi')" | sed -n 's/^.$//i')"
	VM_DISK_DIR="${VM_DISK_DIR:-$VBOX_VM_PATH/$_vm}"
	_vbox_manage 10 createmedium "disk" \
		--filename "$VM_DISK_DIR/$_vm.$_vm_disk_type" \
		--format "$_vm_disk_format" \
		--variant "$_vm_disk_variant" \
		--size $((vm_disk_size*1024))
}
function vmms::_attach_disk()
{
	local _vm="$1"
	local _cn="$2"
	declare -l _dt="$vm_disk_type"
	VM_DISK_DIR="$(dirname "$(_vbox_manage 2 showvminfo "$_vm" 2>/dev/null | sed -n 's/^Config file: *//pi')" | sed -n 's/^.$//i')"
	VM_DISK_DIR="${VM_DISK_DIR:-$VBOX_VM_PATH/$_vm}"
	_vbox_manage 12 storageattach  "$_vm" \
		--storagectl "$_cn" \
		--port 0 \
		--device 0 \
		--type hdd \
		--medium "$VM_DISK_DIR/$_vm.$_dt"
}
# TODO: avoid code duplication !!!
function vmms::_add_image_as_disk()
{
	local _vm="$1"
	local _fp="$2"

# 	### add SATA controller, add disk and attach disk to SATA
# 	# TODO controller types are available
# 	# shellcheck disable=SC2034
# 	vm_disk_controller="${vm_disk_controller:="IntelAHCI"}"
# 	vm_disk_controller_name="${vm_disk_controller_name:="SATA"}"
# 	_vbox_manage 12 storagectl  "$_vm" \
# 		--name "$vm_disk_controller_name" \
# 		--add sata \
# 		--controller "$vm_disk_controller" \
# 		--portcount 1 \
# 		--bootable on
	vm_disk_controller_name="$(vmms::_add_storage_controller_sata)"

	# TODO this requires a loop to create multiple disks
	### create hard disk if not disabled (disk count == 0)
	if (( vm_disk_count > 0 )); then
		# TODO switch disk type to vmdk? the upcoming qemu flavour of this script could use that one out of the box
		declare -l _vm_disk_type="$vm_disk_type"
		declare -u _vm_disk_format="$vm_disk_type" # TODO: correct? see ~20 lines below. seems to be correct
		declare -A _vm_disk_variants
		### translate internal key words to vbox command options
		_vm_disk_variants[dynamic]="Standard"
		_vm_disk_variants[fixed]="Fixed"
		### ensure array keys to be lower cased
		declare -l _vm_disk_alloc="${vm_disk_alloc}" # other way to lower the case: _vm_disk_alloc="${vm_disk_alloc,,}"
		_vm_disk_variant=${_vm_disk_variants[$_vm_disk_alloc]}
		### create hard disk if not disabled (disk count == 0)
		VM_DISK_DIR="$(dirname "$(_vbox_manage 2 showvminfo "$_vm" 2>/dev/null | sed -n 's/^Config file: *//pi')" | sed -n 's/^.$//i')"
		VM_DISK_DIR="${VM_DISK_DIR:-$VBOX_VM_PATH/$_vm}"
		# TODO disk creation is a critical process, that might fail! on error user shall be informed!
		# one of the common errors: VBox GUI does bot delete all files, although told so! (if file still
		# exists with the name we create automatically, the createmedium will fail!
# # 		_vbox_manage 10 createmedium "disk" \
# # 			--filename "$VM_DISK_DIR/$_vm.$_vm_disk_type" \
# # 			--format "$_vm_disk_format" \
# # 			--variant "$_vm_disk_variant" \
# # 			--size $((vm_disk_size*1024))
# 		_vbox_manage 12 storageattach  "$_vm" \
# 			--storagectl "$vm_disk_controller_name" \
# 			--port 0 \
# 			--device 0 \
# 			--type hdd \
# 			--medium "$VM_DISK_DIR/$_vm.$vm_disk_type"
		vmms::_attach_disk "$_vm" "$vm_disk_controller_name"
	fi
}
# TODO: avoid code duplication !!!
function vmms::_add_new_empty_disk()
{
	local _vm="$1"
	
# 	### add SATA controller, add disk and attach disk to SATA
# 	# TODO controller types are available
# 	# shellcheck disable=SC2034
# 	vm_disk_controller="${vm_disk_controller:="IntelAHCI"}"
# 	vm_disk_controller_name="${vm_disk_controller_name:="SATA"}"
# 	_vbox_manage 12 storagectl  "$_vm" \
# 		--name "$vm_disk_controller_name" \
# 		--add sata \
# 		--controller "$vm_disk_controller" \
# 		--portcount 1 \
# 		--bootable on
	vm_disk_controller_name="$(vmms::_add_storage_controller_sata)"
	
	# TODO this requires a loop to create multiple disks
	### create hard disk if not disabled (disk count == 0)
	if (( vm_disk_count > 0 )); then
		printf "creating $vm_disk_count disk(s) of $vm_disk_size GB type '$vm_disk_type'\n" >&2
		
# 		# TODO switch disk type to vmdk? the upcoming qemu flavour of this script could use that one out of the box
# 		declare -l _vm_disk_type="$vm_disk_type"
# 		declare -u _vm_disk_format="$vm_disk_type" # TODO: correct? see ~20 lines below. seems to be correct
# 		declare -A _vm_disk_variants
# 		### translate internal key words to vbox command options
# 		_vm_disk_variants[dynamic]="Standard"
# 		_vm_disk_variants[fixed]="Fixed"
# 		### ensure array keys to be lower cased
# 		declare -l _vm_disk_alloc="${vm_disk_alloc}" # other way to lower the case: _vm_disk_alloc="${vm_disk_alloc,,}"
# 		_vm_disk_variant=${_vm_disk_variants[$_vm_disk_alloc]}
# 		# TODO disk creation is a critical process, that might fail! on error user shall be informed!
# 		# one of the common errors: VBox GUI does bot delete all files, although told so! (if file still
# 		# exists with the name we create automatically, the createmedium will fail!
# 		VM_DISK_DIR="$(dirname "$(_vbox_manage 2 showvminfo "$_vm" 2>/dev/null | sed -n 's/^Config file: *//pi')" | sed -n 's/^.$//i')"
# 		VM_DISK_DIR="${VM_DISK_DIR:-$VBOX_VM_PATH/$_vm}"
# 		_vbox_manage 10 createmedium "disk" \
# 			--filename "$VM_DISK_DIR/$_vm.$_vm_disk_type" \
# 			--format "$_vm_disk_format" \
# 			--variant "$_vm_disk_variant" \
# 			--size $((vm_disk_size*1024))
		vmms::_create_disk "$_vm"

# 		_vbox_manage 12 storageattach  "$_vm" \
# 			--storagectl "$vm_disk_controller_name" \
# 			--port 0 \
# 			--device 0 \
# 			--type hdd \
# 			--medium "$VM_DISK_DIR/$_vm.$vm_disk_type"
		vmms::_attach_disk "$_vm" "$vm_disk_controller_name"
	fi
}
function vmms::_add_ide_and_iso_image()
{
	# TODO: separate this into adding controller and adding iso?
	local _vm="$1"
	local _fp="$2"
	### mimik the behaviour of the GUI as good as we can
	### --port 0 --device 0 = Primary Master
	### --port 0 --device 1 = Primary Slave
	### --port 1 --device 0 = Secondary Master
	### --port 1 --device 1 = Secondary Slave
	_vbox_manage 6 storagectl  "$_vm" \
		--name "IDE" \
		--add ide
	_vbox_manage 12 storageattach  "$_vm" \
		--storagectl "IDE" \
		--port 1 \
		--device 0 \
		--type dvddrive \
		--medium "$_fp"
}
function vmms::create_vm_with_disk_image()
{
	local _vm="$1"

	_created=1

	vmms::_create_vm "$_vm" \
	&& vmms::_create_vdi_image_from_raw_image "$_vm" "$filepath" \
	&& vmms::_add_image_as_disk "$_vm" "$filepath" \
	&& _created=0
	
	return $_created
}
function vmms::create_vm_from_iso_image()
{
	local _vm="$1"

	_created=1

	vmms::_create_vm "$_vm" \
	&& vmms::_add_ide_and_iso_image "$_vm" "$filepath" \
	&& vmms::_add_new_empty_disk "$_vm" \
	&& _created=0
	
	return $_created
}



function vmms::vm_unattended_install()
{
  # a sample command:
  # ? VBoxManage unattended install $VM \
  # --iso=$HOME/Downloads/ISOs/Linux/Oracle/OracleLinux-R7-U6-Server-x86_64-dvd.iso \
  # --user=<login> --password=<password> --full-user-name=<name> \
  # --locale=<ll_CC> --country=<CC> --time-zone=<tz> --hostname=<fqdn> --language=<lang> \
  # --install-additions --start-vm=<session-type>

  #   $ ll /usr/share/virtualbox/UnattendedTemplates/
  #   insgesamt 156
  #   -rw-r--r-- 1 root root 11440 Jul 12 22:01 debian_postinstall.sh
  #   -rw-r--r-- 1 root root  3331 Jul 12 22:01 debian_preseed.cfg
  #   -rw-r--r-- 1 root root  2165 Jul 12 22:01 fedora_ks.cfg
  #   -rw-r--r-- 1 root root  2164 Jul 12 22:01 lgw_ks.cfg
  #   -rw-r--r-- 1 root root 17596 Jul 12 22:01 lgw_postinstall.sh
  #   -rw-r--r-- 1 root root  2680 Jul 12 22:01 ol_ks.cfg
  #   -rw-r--r-- 1 root root 12231 Jul 12 22:01 ol_postinstall.sh
  #   -rw-r--r-- 1 root root 15581 Jul 12 22:01 os2_cid_install.cmd
  #   -rw-r--r-- 1 root root  7574 Jul 12 22:01 os2_response_files.rsp
  #   -rw-r--r-- 1 root root  7880 Jul 12 22:01 os2_util.exe
  #   -rw-r--r-- 1 root root  2681 Jul 12 22:01 redhat67_ks.cfg
  #   -rw-r--r-- 1 root root 11653 Jul 12 22:01 redhat_postinstall.sh
  #   -rw-r--r-- 1 root root  3930 Jul 12 22:01 rhel3_ks.cfg
  #   -rw-r--r-- 1 root root  3298 Jul 12 22:01 rhel4_ks.cfg
  #   -rw-r--r-- 1 root root  3184 Jul 12 22:01 rhel5_ks.cfg
  #   -rw-r--r-- 1 root root  4122 Jul 12 22:01 ubuntu_preseed.cfg
  #   -rw-r--r-- 1 root root  1859 Jul 12 22:01 win_nt5_unattended.sif
  #   -rw-r--r-- 1 root root 14535 Jul 12 22:01 win_nt6_unattended.xml
  #   -rw-r--r-- 1 root root  7343 Jul 12 22:01 win_postinstall.cmd

  # https://wiki.debian.org/DebianInstaller/Preseed
  # https://wiki.debian.org/DebianInstaller/Preseed#Examples
  # https://www.debian.org/releases/stable/amd64/apb.en.html
  # https://www.debian.org/releases/stable/example-preseed.txt
  # https://www.debian.org/releases/bookworm/example-preseed.txt
  # https://github.com/pwlin/debian-preseed/tree/master
  # https://fak3r.com/2011/08/18/automate-debian-installs-via-preseed/
  # https://sites.tntech.edu/renfro/2007/04/17/unattended-debian-installations-or-how-i-learned-to-stop-worrying-and-love-the-preseedcfg/

  local _iso="$1"
}

function vmms::is_vm_unattended_install_supported()
{
  # a sample command:
  # $ VBoxManage unattended detect --iso=/home/christian/Downloads/ISOs/Linux/debian/debian-11.1.0-amd64-DVD-1.iso --machine-readable
  #   VBoxManage: info: Detected '/home/christian/Downloads/ISOs/Linux/debian/debian-11.1.0-amd64-DVD-1.iso' to be:
  #     OS TypeId    = Debian_64
  #     OS Version   = 11.1.0 "Bullseye"
  #     OS Flavor    = Debian GNU/Linux
  #     OS Languages = en-US
  #     OS Hints     =
  #     Unattended installation supported = yes   <<< !!!
  local _iso="$1"
}


# # TODO: create a unique timestamp or just random number instead of DUMMY
# function vmms::create_vm_group() # "$VMG"
# {
# 	local _vmg="$1"
# 	_created=1
# 	_vbox_manage 6 createvm --name "DUMMY" --ostype "other" --register # TODO: register required? > Yes
# 	_vbox_manage 6 modifyvm "DUMMY" --groups "${_vmg}"
# 	_vbox_manage 3 unregistervm "DUMMY" --delete # NOTE: this does remove the empty group as well and so the whole attempt is pretty useless
# 	_created=0
# 	return $_created
# }


# TODO: if possible this function shall not create
#       group on the fly if it does not exists before
# NOTE: it now takes the argument as given. i.e.
#       requires starting with a slash
# NOTE: for unknown reasons this cli does _not_ move
#       the vm directory into the group directory on 
#       disk as well, such as the gui does
function vmms::move_vm_to_group() # "$VM" "$VMG"
{
	# create vm group on the fly if it does not exists yet!
	local _vm="$1"
	local _vmg="$2"
	_moved=1
	_vbox_manage 4 modifyvm "$_vm" --groups "$_vmg"
	_moved=0
	return $_moved
}
# NOTE: VBox has kind of a weird command line options here
function vmms::remove_vm_from_group() # "$VM" "$VMG"
{
	# cerate vm group o the fly if it does not exists yet - not needed!
	local _vm="$1"
	_removed=1
	### to ungroup the command takes an option with an empty argument
	_vbox_manage 4 modifyvm "$_vm" --groups ""
	_removed=0
	return $_removed
}


# TODO: as of https://adirmeier.de/Blog/ID_119
#       it might be required to check out the disk first
#       > actualy it does not look like this!
#       > this command leaves just the *.vbox file, such
#       > as the gui does !?
function vmms::delete_vm() # "$VM"
{
	local _vm="$1"
# 	# TODO: get the controller type from vm first?
# 	VBoxManage storageattach "${_vm}" --storagectl "SATA Controller" --port 0  --device 0 --type hdd --medium none
# 	VBoxManage closemedium disk "${_vm}.vdi" --delete
	_vbox_manage 3 unregistervm "${_vm}" --delete
}
function vmms::get_vm_state()
{
	_vbox_manage 2 showvminfo "${_vm}" | grep '^State:' | grep --extended-regexp 'saved|running|powered off|aborted-saved' --only-matching
}
function vmms::vm_has_saved_state()
{
	_vbox_manage 2 showvminfo "${_vm}" | grep '^State:' | grep --extended-regexp 'saved|aborted-saved' --quiet
}
function vmms::export_vm() # "$VM"
{
	local _vm="$1"
	local _fp="$2"
	### check if file exists and vm name is not empty
	test -n "$_fp" || return 1
	test -n "$_vm" || return 1
	_exported=1
	ova_export_filename="$_fp"
	### run dolly run
	printf '%s\n' 'exporting may take a while. Be patient...'
	_vbox_manage 3 export "${_vm}" --output="${ova_export_filename}" && _exported=0
	return $_exported
}
function vmms::import_applicance() # "$VM"
{
	local _fp="$1"
	local _vm="$2"
# 	local _os="$3"
	### check if file exists and vm name is not empty
	test -f "$_fp" || return 1
	test -n "$_vm" || return 1
	# TODO this is a long running process .. make use of kdialog showprocess
	_vbox_manage 6 import "$_fp" --vsys 0 --vmname "$_vm"
	# avoid full screen if possible / doable
	# https://forums.virtualbox.org/viewtopic.php?f=6&t=92354
	# https://www.virtualbox.org/manual/ch09.html#legacy-fullscreen-mode
	# UNTESTED
 	_vbox_manage 4 setextradata "$_vm" "GUI/Fullscreen" false
}
function _vbox_list_vms_helper_getter()
{
	# TODO: in desktop mode this lists the simple names. instead it should list the real 'Name' from .desktop files # DONE!
	local -l _my_vendor_prefix="org.${MY_NEW_NAME}"
	local _application_desktop_dir="${HOME}/.local/share/applications/${MY_NEW_NAME}" # this should be a global ENV
# 	_application_desktop_filename="${_my_vendor_prefix}.vm.$(_get_simple_name "$_vm").desktop"
# 	_application_desktop_filepath="${_application_desktop_dir}/${_application_desktop_filename}"
	if $desktop; then
	  (
		cd ${_application_desktop_dir}/
# 		ls -1 *.desktop | sed "s/${_my_vendor_prefix}\.vm\.//" | sed 's/\.desktop//'
		cat *.desktop | grep '^Name=' | sed 's/^Name=//'
	  )
	else
		_vbox_manage 2 list vms | sed 's/ {.*}//gi' | sed 's/"//g'
	fi
}
function _vbox_list_vms_helper_sorter()
{
# 	( echo; sort --numeric-sort --reverse )
#	( echo; sort --numeric-sort )
# 	( sort --numeric-sort -k 2 -r )  # | sort -k 2 -r
	sort --numeric-sort -k 2 -r
}
function _vbox_list_vms_helper_prefix()
{
	sed ''
}
function vmms::list_vms() # -
{
# 	_vbox_manage 3 list vms | cut -d '"' -f 2 | sort
	echo
# 	_vbox_manage 2 list vms | sed 's/ {.*}//gi' | sed 's/"//g'
	_vbox_list_vms_helper_getter | _vbox_list_vms_helper_sorter
}
function vmms::list_vms_running() # -
{
	echo
	_vbox_manage 2 list runningvms | cut -d '"' -f 2 | _vbox_list_vms_helper_sorter
}
function vmms::list_vms_stopped() # -
{
	(
		_vbox_manage 2 list vms | cut -d '"' -f 2
		_vbox_manage 2 list runningvms | cut -d '"' -f 2
	) \
	| ( echo; sort ) | uniq --unique
}
function vmms::power_off_vm()
{
	local _vm="$1"
# 	local _force="$2"
	echo "power off..." >&2
	_vbox_manage 3 controlvm "$_vm" poweroff
}
function vmms::acpi_power_off_vm()
{
	local _vm="$1"
# 	local _force="$2"
	echo "acpi power off..." >&2
	_vbox_manage 3 controlvm "$_vm" acpipowerbutton
}
function vmms::purge_vm_saved_state()
{
	local _vm="$1"
 	_vbox_manage 2 discardstate "$_vm"
}
# TODO: common name scheme? all starting with vm_?
# TODO: could / should be merged with vmms::list_vms (checkig for given argument)
# TODO: or modify this into a more complex search function
function vmms::query_vm() # "$QUERY"
{
	local _vm="$1"
# 	vmms::list_vms | ( echo; grep -i -e "$_vm" ) | sort
	# treat distro version numbers as being important and list newest first
	_vbox_list_vms_helper_getter | grep -i -e "^$_vm" | _vbox_list_vms_helper_sorter
}
# TODO: common name scheme? all starting with vm_?
function vmms::reboot_vm() # "$VM"
{
	local _vm="$1"
	echo "rebooting..." >&2
}
# TODO: common name scheme? all starting with vm_?
function vmms::rename_vm() # "$OLD_VM_NAME" "$NEW_VM_NAME"
{
	local _vm_old="$1"
	local _vm_new="$2"
	_vbox_manage 4 modifyvm "$_vm_old" --name "$_vm_new"
}
# TODO: common name scheme? all starting with vm_?
function vmms::snap_vm() # "$VM"
{
	local _vm="$1"
	if vmms::vm_is_running "${_vm}"; then
		_vbox_manage 5 snapshot "$_vm" take "snapshot-${TODAY}" --live
	else
		_vbox_manage 4 snapshot "$_vm" take "snapshot-${TODAY}"
	fi
}
# TODO: common name scheme? all starting with vm_?
function vmms::start_vm() # "$VM"
{
	local _vm="$1"
	_vbox_manage 4 startvm "$_vm" --type "gui"
}
# TODO: common name scheme? all starting with vm_?
function vmms::stop_vm() # "$VM"
{
	local _vm="$1"
	echo "stopping..." >&2
	_vbox_manage 3 controlvm "$_vm" savestate
}
function vmms::vm_exists() # "$VM"
{
	local _vm="$1"
	### list vms, remove uuids, removes leading and trailing "s
	_vbox_manage 2 list vms | sed 's/ {.*}//gi' | sed 's/^"//' | sed 's/"$//' | grep --quiet --line-regexp "$_vm"
# 	_vbox_manage --quiet 3 list vms | sed 's/ {.*}//gi' | grep --quiet -w "$_vm"
}
function vmms::vm_info() # "$VM"
{
	local _vm="$1"
	local _default_options='--machinereadable'
	local _options=''
	if $human_readable; then
		_options=''
	else
		_options="$_default_options"
	fi
# 	VBoxManage showvminfo "$_vm" "$_options"
	_vbox_manage 3 showvminfo "$_vm" "$_options"
}
function vmms::vm_is_powered_off() # "$VM"
{
	local _vm="$1"
	_vbox_manage --quiet 2 showvminfo "$_vm" | grep --quiet 'powered off' && return 0
	return 1
}
function vmms::vm_is_running() # "$VM"
{
	local _vm="$1"
#  	_vbox_manage --quiet 2 list runningvms | sed 's/ {.*}//gi' | sed 's/^"//' | sed 's/"$//' | grep --quiet --line-regexp "$_vm"
 	_vbox_manage 2 showvminfo "$_vm" | grep 'State:' | grep --quiet 'running'
}
function vmms::vm_is_stopped() # "$VM" # stopped is defined here as: *not* running
{
	local _vm="$1"
	vmms::vm_is_running "$_vm" && return 1
	return 0
}
# function vmms::open_vm()
# {
# 	local _vm="$1"
# 	local _protocol="$2"
# 	case ${_protocol} in
# 		http )
# 			_port=$(_vbox_manage 3 getextradata "$_vm" 'vmmcon-tcp-http-port' | sed 's/[^0-9]//g')
# 		;;
# 		https )
# 			_port=$(_vbox_manage 3 getextradata "$_vm" 'vmmcon-tcp-https-port' | sed 's/[^0-9]//g')
# 		;;
# # 		ssh )
# # 			local _vm_tcp_ssh_port=$(vmms::get_ssh_port "${_vm}")
# # 		;;
# 		* )
# 		;;
# 	esac
# 	printf '%s' "localhost:${_port}"
# }
function vmms::vm_state() # not used currently
{
	local _vm="$1"
	_state=$(_vbox_manage --quiet 2 showvminfo "$_vm" | grep --extended-regexp 'powered off|saved|running' --only-matching)
	case "$_state" in
		'powered off')
			print 'poweroff'
			break
		;;
		'saved')
			print 'stopped'
			break
		;;
		*)
			print "$_state"
			break
		;;
	esac
}

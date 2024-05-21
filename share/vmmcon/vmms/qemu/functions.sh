#
# share/vmmcon/vmms/qemu/functions.sh
#

# virsh(1) is kinda the same thing as vmmctl / vmmcon! so we end up with a wrapper
# in a wrapper. this does not make sense. Are you for real? No, as the basic and
# most advanced feature of vmmcon is to create new Vms on predefined sets of
# setup configurations and *this* is not part of virsh. Although virsh(1) can
# handle vbox internally as well, but likely this is not the default mode it
# operates and we do not know how good the software quality is.

# on the other hand: the main and original purpose of the *.desktop "application"
# is to create most easily (and automagically) a new VM from an ISO.
# https://www.thegeekstuff.com/2014/10/linux-kvm-create-guest-vm/

# https://joshrosso.com/docs/2020/2020-05-06-linux-hypervisor-setup/

# virsh(1) *is* the counterpart of vboxmanage
# https://cyanogenmods.org/kvm-vs-virtualbox/
# https://www.thomas-krenn.com/de/wiki/Virsh_-_Kommandozeilenwerkzeug_zur_Verwaltung_virtueller_Maschinen

# COMMENT
# although qemu 7 kvvm / libvirt uses the term domain,
# we use vm for consistency with the rest of this application

_set_vir_sh_command()
{
	_vir_sh_command="$(type -p virsh)" # likely virsh knows about host architecture
}
_set_vir_sh_command



_vir_sh ()
{
	[[ $1 = $# ]] || _error_exit "actual argument count ($#) does not match given argument count ($1) ($LINENO)"
	shift 1 # argument count
	printf 'running external command: %s\n' "$_vir_sh_command $*" >&2
	$dry || $_vir_sh_command "$@"
}



vmms::create_desktop_entry () # "$VM"
{
	local _vm="$1"
}
vmms::import_applicance () # "$VM"
{
	local _fp="$1"
	local _vm="$2"
# 	local _os="$3"
	### check if file exists and vm name is not empty
	test -f "$_fp" || return 1
	test -n "$_vm" || return 1
}
vmms::export_applicance () # "$VM"
{
	:
}
vmms::vm_exists () # "$VM"
{
	local _vm="$1"
	_vir_sh 3 list --all | awk '{print $2}' | grep -q -w "$_vm" && return 0
	return 1
}
vmms::vm_is_running () # "$VM"
{
	local _vm="$1"
	_vir_sh 3 list --state-running | awk '{print $2}' | grep -q -w "$_vm" && return 0
	return 1
}
vmms::vm_is_stopped () # "$VM"
{
	local _vm="$1"
# 	vmms::vm_is_running "$_vm" && return 1
	_vir_sh 3 list --state-shutoff | awk '{print $2}' | grep -q -w "$_vm" && return 0
	_vir_sh 3 list --state-paused | awk '{print $2}' | grep -q -w "$_vm" && return 0
# 	return 0
}
vmms::info_vm () # "$VM"
{
	# TODO shall we have a XSLT to transform to a vbox like output?
	local _vm="$1"
	local _default_options='--machinereadable'
	local _options=''
	if $human_readable; then
		_options=''
	else
		_options="$_default_options"
	fi

	# 	_vir_sh 3 dumpxml "$_vm"
	# an alternate command:
	_vir_sh 3 dominfo "$_vm"
}
vmms::list_vms () # -
{
#           ``virsh`` list
#             Id    Name                           State
#           ----------------------------------------------------
#             0     Domain-0                       running
#             2     fedora                         paused

	_vir_sh 3 list --all | awk '{print $2}' # default: list running domains
}
vmms::list_vms_running () # -
{
# 	VBoxManage list runningvms | cut -d '"' -f 2 | sort
# 	_vbox_manage 3 list runningvms | cut -d '"' -f 2 | sort
	_vir_sh 2 list | awk '{print $2}' # default: list running domains
}
vmms::list_vms_stopped () # -
{
	# TODO use virsh(?)
# 	(
# 		VBoxManage list vms | cut -d '"' -f 2
# 		VBoxManage list runningvms | cut -d '"' -f 2
# 		_vbox_manage 3 list vms | cut -d '"' -f 2
# 		_vbox_manage 3 list runningvms | cut -d '"' -f 2
# 	) \
# 	| sort | uniq --unique
	_vir_sh 3 list --inactive # default: list running domains
}
vmms::query_vm () # "$QUERY"
{
	local _vm="$1"
	vmms::list_vms | grep -i -e "$_vm" | sort
}
vmms::create_vm () # "$VM"
{
	# TODO use virt-install() (part of virt-manager)
	#      https://unix.stackexchange.com/questions/309788/how-to-create-a-vm-from-scratch-with-virsh
	#      https://documentation.suse.com/sles/15-SP1/html/SLES-all/cha-libvirt-storage.html

	# NOTE virt-manager uses qemu:///system by default (and likely therefore puts disk images into /var/lib/libvirt requiring root)
	#      whereas virsh uitilizes qemu:///user uri instead.

	# is this a default place for user images?
	# /home/christian/.local/share/libvirt/images
	# https://ostechnix.com/how-to-change-kvm-libvirt-default-storage-pool-location/

	# disks are created if they do not exist:
	# https://linuxconfig.org/how-to-create-and-manage-kvm-virtual-machines-from-cli

	# virt-install will start the new VM by default ... likely there is an option to disable this behaviour
	# https://serverfault.com/questions/919538/do-not-start-guest-after-virt-install   > --noreboot  , nach Installation nicht automatisch starten, hmmm
	# there is also: --noautoconsole

	# do not use the system wide directories:
	# - qemu:///user (or qemu:///session ?)

	local _vm="$1"
	_created=1

	# a sample from the arch wiki
	# 	$ virt-install \
	# 	--name arch-linux_testing \
	# 	--memory 1024             \
	# 	--vcpus=2,maxvcpus=4      \
	# 	--cpu host                \
	# 	--cdrom $HOME/Downloads/arch-linux_install.iso \
	# 	--disk size=2,format=qcow2  \
	# 	--network user            \
	# 	--virt-type kvm

	# trying to bring this in line with my options...
	# 	$ virt-install \
	# 	--name "$_vm" \
	# 	--memory $vm_memory_size \
	# 	--vcpus=$vm_cpu_count \
	# 	--cpu host \
	# 	--cdrom "$filepath" \
	# 	--os-type=generic \ --os-variant="$vm_ostype" \
	# 	--disk bus=virtio,format=qcow2,path=</var/lib/libvirt/images/myRHELVM1.img>,size=$vm_disk_size \  # do NOT want the image in such a protected place with likely restricted storage
	# 	--network user \
	# 	--virt-type 'kvm'

# 	_vbox_manage 7 createvm --name "$_vm" --ostype "$vm_ostype" --register
	# virsh define filename.xml ?

	### domain name shall not contain blanks TODO with bash internals?
	_vm="$(printf '%s' "$_vm" | sed 's/ /_/g')"

	## strip '(' and ')' as well
	_vm="$(printf '%s' "$_vm" | sed 's/[()]//g')"

	# TODO: will the disk be created or shall we do this beforehand?

	virt-install \
	--name "$_vm" \
	--memory $vm_memory_size \
	--vcpus=$vm_cpu_count \
	--cpu host \
	--cdrom "$filepath" \
	--os-type='Linux' \ --os-variant="$vm_ostype" \
	--disk size=$vm_disk_size,format=qcow2 \
	--network user \
	--virt-type 'kvm' && _created=0

# 	--description "Test VM with CentOS 7" # could take my comment

	# for an installation via virsh see:
	# https://computingforgeeks.com/virsh-commands-cheatsheet/

	return $_created
}
vmms::open_vm () # "$VM"
{
	local _vm="$1"
# 	echo "opening $_vm..." >&2
# 	_vir_sh 3 start "$_vm" # (a (previously defined) inactive domain)
# 	virt-manager --connect qemu:///system --show-domain-console "$_vm"
	vmms::start_vm "$_vm"
	vmms::view_vm "$_vm"
	return 0
}
vmms::view_vm () # "$VM"
{
	# TODO this could / should be a cascade as there are many options to "view"
	local _vm="$1"
	echo "viewing $_vm..." >&2
# 	qemu-system-x86_64 ...
# 	qemu-system-x86_64-spice ...
# 	virt-viewer --reconnect --wait --zoom=100 "$_vm"
	# TODO session or system?
# 	https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/7/html/virtualization_deployment_and_administration_guide/sect-generic_commands-connect
# 	qemu:///session - connects locally as a user to the user's set of guest local
#                     machines using the KVM hypervisor.
# 	qemu:///system -  connects locally as the root user to the daemon supervising
#                     guest virtual machines on the KVM hypervisor.
# 	virt-manager --connect qemu:///session --show-domain-console "$_vm"
	virt-manager --connect qemu:///system --show-domain-console "$_vm"
	return 0
}
vmms::start_vm () # "$VM"
{
	local _vm="$1"
	echo "starting $_vm..." >&2
# 	_vbox_manage 5 startvm "$_vm" --type "gui"
	_vir_sh 3 start "$_vm" # (a (previously defined) inactive domain)
# 	qemu-system-x86_64 ...
# 	qemu-system-x86_64-spice ...
# 	virt-viewer "$_vm" &
# 	vmms::view_vm "$_vm"
# 	virt-manager --connect qemu:///system --show-domain-console "$_vm"
	return 0
}
vmms::stop_vm () # "$VM"
{
	local _vm="$1"
	echo "stopping..." >&2
# 	_vbox_manage 4 controlvm "$_vm" savestate
	_vir_sh 3 shutdown "$_vm"
}
vmms::reboot_vm () # "$VM"
{
	local _vm="$1"
	echo "rebooting..." >&2
	_vir_sh 3 reboot "$_vm"
}
vmms::power_off_vm ()
{
	local _vm="$1"
	echo "power off..." >&2
	_vir_sh 3 destroy "$_vm"
}

# TODO?
# suspend (aka pause)
# resume (from suspend)

vmms::clone_vm () # "$VM" # TODO should be  FROM_VM  NEW_VM
{
	# TODO use virt-clone () (part of virt-manager)

	local _vm="$1"
	_cloned=1

# 	local _vm_to_clone="$1"
# 	local _new_vm="$2"

	# TODO do not interact with the user here

	### create a new name (either append (C), append a new time stamp or both
	_vm_to_clone_name="$_vm"
	if [[ -n "$STAMP" ]]; then
		vm_name_suggest="${_vm_to_clone_name} (C) (${STAMP})"
	else
		vm_name_suggest="${_vm_to_clone_name} (C) (${TODAY})"
	fi
	_verbose "vm_name_suggest=${vm_name_suggest}" >&2
	### get confirmation for name for the cloned virtual machine
	if [[ $yes = true ]]; then
		vm_name="${vm_name_suggest}"
	else
		if ! vm_name=$(_get_vm_name "${vm_name_suggest}"); then
			_canceled_exit
		fi
	fi

	### run dolly run
	# TODO again: no interaction here
	printf '%s\n' 'cloning may take a while. be patient...'
	###_vbox_manage 6 clonevm "${_vm_to_clone_name}" --name="${vm_name_suggest}" --mode="machine" --register && _cloned=0
	virt-clone \
		--original "${_vm_to_clone_name}" \
		--auto-clone \
		--name "${vm_name_suggest}" && _cloned=0

	### done that
	return $_cloned
}
vmms::rename_vm () # "$OLD_VM_NAME" "$NEW_VM_NAME"
{
	local _vm_old="$1"
	local _vm_new="$2"
# 	_vbox_manage 5 modifyvm "$_vm_old" --name "$_vm_new"
	_vir_sh 4 domrename "$_vm_old" "$_vm_new"
}
vmms::delete_vm () # "$VM"
{
	local _vm="$1"
	# _warning is a reasonable option here
# 	_warning "Delete VM: '$_vm'" && _vbox_manage 4 unregistervm "$_vm" --delete
	_warning "Delete VM: '$_vm'" && _vir_sh 7 undefine "$_vm" --managed-save --snapshots-metadata --remove-all-storage --wipe-storage
}

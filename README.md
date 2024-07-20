# vmmcon / vmmctl / hypercon / hopper

(final naming not decided yet)

> **this is work-in-progress and has works-for-me status only!**

## Abstract

A VM console tool to first and foremost create new VMs from predefined VM config sets. Secondly it allows a couple of operations on existing VMs. Supported hypervisors are VirtualBox, QEMU (with KVM), may be VMware (workstation) later.

## Intention

This tool has been created originaly to reverse the use of tools, when it comes to create VMs. This tool starts with a downloaded ISO image and anything goes from that. From the name of the ISO image file a VM "profile" is selected automatically and the VM created the same, including disks, networtk, main memory, bit size, BIOS/UEFI settings and many more aspects of the new VM.

The core of this tool is a large Bash script. Additionaly it comes with some Desktop Integration parts, that allow direct creation after a download or double clicking an ISO image file. On top new VMs are created as Desktop Application files following the XDG standard for it.

## TODO

- support unattended setups wherever possible
- support for QEMU/KVM, VMware
- pre configs in JSON
- TUI interface
- disable manual profile selection
- m4 based build script
- complete abstraction from KDE (or other DE)
- user configurable alias commands
- extract initial desktop integration parts
- respect user env profile settings
- complete refactor it

## Common Commands / Basic Usage

```
Usage: vmmcon <command> [options] [<iso-image-file> | <vm-name>]

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
  -S | --stamp <stamp>          Append <stamp> instead of TODAY to vm name
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
```

## Installation

A list of relevant files and directories (user installation)

Base files (VBox only):

```
~/.bash_completion.d/vmmcon
~/.config/vmmconrc
~/.local/bin/vmmcon
~/.local/share/vmmcon/vmms/vbox/functions.sh
~/.local/share/vmmcon/locale/de/LC_MESSAGES/create-vm-from-iso-vbox.*
~/.local/share/vmmcon/automagic.csv
~/.local/share/vmmcon/automagic.local.csv
~/.local/share/vmmcon/matches/*.conf
~/.local/share/vmmcon/profiles/*.conf
~/.local/share/vmmcon/automagic.json
~/.local/share/vmmcon/templates/xdg/desktop-entry-template.desktop
~/.local/share/vmmcon/templates/xdg/desktop-menu-category.directory
~/.local/share/vmmcon/templates/xdg/desktop-menu-category.menu
~/.local/share/vmmcon/icons/display-and-tower.svg
```

Directories used:

```
~/.local/share/applications/vmmcon/
~/.local/share/desktop-directories/
~/.config/menus/applications-merged/
```

KDE desktop integration (Plasma 5):

```
~/.local/share/kservices5/ServiceMenus/create-vm-from-iso-vbox.desktop
```

KDE desktop integration (Plasma 6):

```
~/.local/share/kio/servicemenus/create-vm-from-iso-vbox.desktop
```


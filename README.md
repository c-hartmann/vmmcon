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
- complete abstarction from KDE
- user configurable alias commands
- extract initial desktop integration parts
- respect user env profile settings
- complete refactor it

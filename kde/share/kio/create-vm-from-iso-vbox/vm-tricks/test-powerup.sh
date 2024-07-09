#!/bin/bash
pwr=false

if ! $pwr ; then
	kdialog --title "CreateVBoxVMfromISO" --icon virtualbox --yesno "New VM added:\n\"$vm_name\".\nPower up now?" --yes-label "Power Up" --no-label "No Thanx"
	test $? -eq 0 && pwr=true
fi
if $pwr ; then
	# run vbox, run
	echo VBoxManage startvm "$vm_name" --type gui # or headless?
else
	notify-send --app-name="Create VBox VM from ISO" --icon=virtualbox --expire-time=6000 "New VM not started"
fi

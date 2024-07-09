#!/bin/bash

### initialize dialog type
declare gui
declare cli
declare cli_basic
declare cli_fancy
if [[ -t 0 ]]; then
	# running in command line
	gui=false
	cli=true
	if [[ -n "$(which dialog)" ]]; then
		# see: https://www.youtube.com/watch?v=A_QErp5C-z0
		# fancy command line mode
		cli_fancy=true
		cli_basic=false
		echo "love you have dialog on your host"
	else
		# basic command line mode
		cli_basic=true
		cli_fancy=false
		echo -e "\e[32m\e[1mhint\e[0m: Consider to install '\e[1mdialog\e[0m' on your host to enable fance command line style for all dialogs herein"
	fi
else
	# running via service menu
	gui=true
	cli=false
fi

echo gui: $gui
echo cli: $cli
echo cli_basic: $cli_basic
echo cli_fancy: $cli_fancy
exit 0

### _dialog
### open either a kdialog when run through service menu (different environment?)
### or create a dialog on command line (any nice command line tool for this?)
_dialog ()
{
	title=$1
	text=$2
	dialog_type=$3

	case $dialog_type in
		--yesno)
			:
			$gui && kdialog --title "$title" --yesno "$text" --yes-label "Sure it is" --no-label "I doubt that"
			$cli_basic && read ...
			$cli_fancy && dialog
		;;
		--msgbox)
			:
		;;
	esac
}

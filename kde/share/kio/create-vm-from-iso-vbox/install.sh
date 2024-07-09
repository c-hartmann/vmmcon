#! /usr/bin/env bash

### a hopefully usefull and mostly generic installer for KDE extensions

# TODO get *correct* do-not-overwrite tar option

# shellcheck disable=SC2034
ME="install.sh"

MY_PATH="${BASH_SOURCE[0]}"
MY_FILE="${MY_PATH##*/}"
MY_NAME="${MY_FILE%%.*}"

### first try
MY_INSTALL_OR_UPDATE_TAR_GZ="install-or-update.tar.gz"
MY_INSTALL_OR_PROTECT_TAR_GZ="install-or-keep.tar.gz"

### second try
MY_INSTALL_UPDATE_TAR_GZ="install-update.tar.gz"
MY_INSTALL_PROTECT_TAR_GZ="install-keep.tar.gz"

### things that can't be accomplished via an archive, go into the extra script
MY_EXTRAS="install-extras.sh"

### cosmetic sugar
MY_TITEL="Dolphin User Service Menu Installer"
MY_ICON="install"



### this should run within a terminal and some gui application
declare gui=false
declare cli=false

### install base dir is either system wide or personaly
base_dir_root="/usr"          # this is risky business
base_dir_user="$HOME/.local"  # outbreaks from here with install-extras only
BASE_INSTALL_DIR="$base_dir_user"

### desktop notifications will vanish after seconds
notification_timeout=4000


### _init_cmd "$@"
### get command from command line if given
_init_cmd ()
{
	if [[ $1 =~ --remove|--delete|--uninstall|--deinstall ]]; then
		cmd='remove'
		shift
	fi
	### beside the option to call this as install[.sh] "--remove" we might operate
	### below false flag as [un|de]install[.sh] (f.i. existing as a symbolic link)
	[[ "${MY_NAME}" =~ ^deinstall.* ]] && cmd=remove
	[[ "${MY_NAME}" =~ ^uninstall.* ]] && cmd=remove
}

### _init_run_mode FD
### wrapper that sets gui or cli mode from terminal type
_init_run_mode ()
{
	local fd=$1
	if [[ ! -t $fd ]]; then
		# running via service menu
		gui=true
		cli=false
	else
		# running from command line
		gui=false
		cli=true
	fi
}

### _init_base_install_dir EUID
### set base install dir to system wide if we run as root
_init_base_install_dir
{
	_euid=$1
	[[ $_euid -eq 0 ]] && BASE_INSTALL_DIR="$base_dir_root"
}

### _notify _message
### wrapper that respects gui or cli mode
_notify ()
{
	$gui && notify-send --app-name="${MY_TITLE}" --icon="${MY_ICON}" --expire-time=$notification_timeout "$@"
	$cli && printf "\n$@\n" >&2
}

### _error_exit _message
### even more simple error handling
_error_exit ()
{
	local error_str="$1"
	$gui && kdialog --error "$error_str: $*" --ok-label "So Sad"
	$cli && printf "\n$error_str: $1\n\n" >&2
	exit ${2:-1}
}

### _install_or_update -
### install or update all base files but keep user modified. remove only empty directories
_install_or_update ()
{
	# extract archive if present
	if [[ -f ./$MY_INSTALL_OR_UPDATE_TAR_GZ ]]; then
		tar --directory=$HOME --extract --verbose --file ./$MY_INSTALL_OR_UPDATE_TAR_GZ
	else
		if [[ -f ./$MY_INSTALL_UPDATE_TAR_GZ ]]; then
			tar --directory=$HOME --extract --verbose --file ./$MY_INSTALL_UPDATE_TAR_GZ
		else
			return false
		fi
	fi
}

### _install_or_keep -
### install all base files but keep user modified
### TODO get correct do-not-overwrite tar option
_install_or_keep ()
{
	# extract archive if present (write files if not present)
	if [[ -f ./$MY_INSTALL_OR_PROTECT_TAR_GZ ]]; then
		tar --directory=$HOME --extract --skip-old-files --verbose --file ./$MY_INSTALL_OR_PROTECT_TAR_GZ
	else
		if [[ -f ./$MY_INSTALL_PROTECT_TAR_GZ ]]; then
			tar --directory=$HOME --extract --skip-old-files --verbose --file ./$MY_INSTALL_PROTECT_TAR_GZ
		fi
	fi
}

### _remove -
### remove all base files but keep user modified. remove only empty directories
_remove ()
{
	if [[ -f ./$MY_INSTALL_OR_UPDATE_TAR_GZ ]]; then
		while read _target; do
			printf '%s\n' "removing: $_target"
			test -f "$_target" && rm "$_target"
			test -d "$_target" && rmdir "$_target"
		done < <(tar tf ./$MY_INSTALL_OR_UPDATE_TAR_GZ | tac)
	else
		return false
	fi
}

### _main "$@"
### welcome to the installation circus
_main ()
{
	local _cmd=$1
	local stdin=0

	# if running inside a terminal, stdin is connected to this terminal
	_init_run_mode $stdin

	# this is made for installations inside users home, but might work global
	_init_base_install_dir $EUID

	# command is optional (defaults to 'install') choose effective
	_init_cmd "$@"

	# choose actions by command effective
	case $_cmd in
		install)
			# files that are installed or updated
			_install_or_update || _error_exit 'oops... no installation archive found'
			# files to install but NOT to update
			_install_or_keep
			# source extras if present
			test -f ./$MY_EXTRAS && . ./$MY_EXTRAS
			# some motivating feedback
			_notify "$MY_TITEL installed"
		;;
		remove)
			_remove || _error_exit 'oops... something went wrong with deinstallation'
			_notify "$MY_TITEL removed"
		;;
		*)
			_error_exit 'oops... something went totaly wrong (unsupported command argument)'
		;;
	esac
}

_main "$@"

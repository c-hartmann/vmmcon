#! /usr/bin/env bash

# TODO do we have to take care, where we are extracted and run?

# TODO this file should be very generic and e.g. use a list of files to install
#      is the tar.gz package still avalailable? (serving as input).
#      where is the source code? dolpin.
# DONE .. BUT .. this the wrong approach, as this can not handle breakouts to
#                upper or parallel directories. and we have to!

# content of a sample install.files.csv
# tyep:path:mode:keep[:owner[:group]]
# d:./hello.txt:755:true
# f:./hello/hello.txt:644:false:root


### THIS...
### shall do the job if used via Dolphin Settings / Configure Dolphin and(!)
### if downloaded to some place
### so .. as this shall be able to install files around the HOME place ... the
### only valid place to build the archives simpley is .. tada .. $HOME
### nice side effect is ... if the user opens the downloaded archive in ark,
### she will have a immediate impression of where these files will go

### second try...
### i come a a gzipped tar file containing ME and a gzipped tar archive
### containing the files to install. so basicly this runs down to extracting
### the tar file to a proper place

### to keep the creation of the distributable tar archive separated .. we might
### create this inside a directory in parallel to the installation directory
### e.g.:
### this is the installation directory: ~/.local/share/servicemenu-download
### so i can go here: ~/.local/share/kde-store-build
### seems not to be a totally dumb idea, as it might serve solid actions and
### plasmoids as well
### solid action go to ~/.local/share/solid/actions/
### plasmoids go to ~/.local/share/plasma/plasmoids/
### service menus go to ~/.local/share/kservices5/ServiceMenus/


### creating the archive with
### $ tar --directory=$HOME --create --verbose --gzip --file install.tar.gz --files-from=<my-files-to-install-list-seen-from-HOME>
### $ tar --directory=$HOME --create --verbose --gzip --file install.tar.gz ./files...
### e.g.
### $ tar --directory=$HOME --create --verbose --gzip --file install.tar.gz ./local/share/kservices5/ServiceMenus/hello-world/
### or
### $ cd $HOME ; tar --create --verbose --gzip --file install.tar.gz ./local/share/kservices5/ServiceMenus/hello-world/

### a real world scenario (with having hello-world/ in ./local/share/kservices5/ServiceMenus/ ...
### package=hello-world
### alias skip-first-line="tail +2"
### cd $HOME
### MY_BUILD_DIR=".local/kde-store-build"
### test -d "$MY_BUILD_DIR" || mkdir "$MY_BUILD_DIR"
### find ./.local/share/kservices5/ServiceMenus/$package | skip-first-line > $MY_BUILD_DIR/$package.files
### cd $MY_BUILD_DIR
### tar --directory=$HOME --create --verbose --gzip --file install.tar.gz --files-from=$package.files
### tar --create --verbose --gzip --file $package.tar.gz install.sh uninstall.sh install.tar.gz

### installing files boiles down to (whereever we live in):
### $ tar --directory=$HOME --extract install.tar.gz

### but cd'ing isn't that a bad idea, as we can do "extra" things from therein without further ado
### $ cd $HOME ; tar --extract install.tar.gz ; bash -c 'do extra stuff from HOME'

ME="install.sh"
MY_FILES_ARCHIVE="install.tar.gz"

ME_EXTRAS="install-extras.sh"

MY_TITEL="Dolphin User Service Menu Installer"
MY_ICON="install"

SCRIPT_DIR="$(dirname "$(readlink -m "$0")")"
DEFAULT_INSTALL_DIR="$HOME/.local/share/servicemenu-download/${MY_ARCHIVE}-dir"

DEFAULT_USER_BIN_DIR="$HOME/.local/bin"

# run mode
declare gui=false
declare cli=false

### _notify
### wrapper that respects gui or cli mode
_notify ()
{
	$gui && notify-send --app-name="${MY_TITLE}" --icon="${MY_ICON}" --expire-time=$notification_timeout "$@"
	$cli && printf "\n$@\n" >&2
}

### _error_exit
### even more simple error handling
_error_exit ()
{
	local error_str="$(gettext "ERROR")"
	$gui && kdialog --error "$error_str: $*" --ok-label "So Sad"
	$cli && printf "\n$error_str: $1\n\n" >&2
	exit ${2:-1}
}

_init_run_mode ()
{
	if [[ ! -t 0 ]]; then
		# running via service menu
		gui=true
		cli=false
	else
		# running from command line
		gui=false
		cli=true
	fi
}

### binaries go to "$HOME/.local/bin" or "/usr/bin"
### symlinks will be created in $first_user_bin_in_path
### desktop acions accompanaiing scripts might be symlinks to "$HOME/.local/bin"

_get_base_install_dir ()
{
	[[ "$EUID" -ne 0 ]] && printf '%s' "$HOME/.local" || printf '%s' "/usr"
}
BASE_INSTALL_DIR="$(_get_base_install_dir)" # use with tar -C "$BASE_INSTALL_DIR" --do-something


### _get_first_user_bin_dir_from_path ( $PATH )
### install-extras.sh might use this to create files or symlinks in variable places
_get_first_user_bin_dir_from_path ()
{
	local _path="$1"
	local _first=""
	_first="$( printf '%s' "$_path" | tr ':' '\n' | grep -e "^${HOME}/" | head -1 )"
	if [[ -d "$_first" ]]; then
		printf '%s' "$_first"
	else
		printf '%s' "${DEFAULT_USER_BIN_DIR}"
	fi
}

### _check_user_bin_dir <user-bin-dir>
### lookout for user bin/ - create if not existing
_check_user_bin_dir ()
{
	local _user_bin_dir="$1"
	test -d "$_user_bin_dir" || mkdir "$_user_bin_dir"
	test -d "$_user_bin_dir" && return true || return false
}

_check_user_bin_dir_in_path ()
{
	local _user_bin_dir="$1"
	local _path="${2:-$PATH}"
	printf '%s' "${_path}" | tr ':' '\n' | grep -q -e "^${_user_bin_dir}$"
}

_main ()
{
	local _user_bin_dir="$(_get_first_user_bin_dir_from_path "$PATH")"

	_check_user_bin_dir "$_user_bin_dir" || _error_exit "user bin dir does not exists or could not be created: $_user_bin_dir"

	_check_user_bin_dir_in_path "$_user_bin_dir" "$PATH" || _notify "user bin dir is not in your binary search \$PATH: $_user_bin_dir"

}

_init_run_mode

_main

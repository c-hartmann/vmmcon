#! /usr/bin/env bash

# this is KDE only, so check this before continue
# TODO ...

### reference to repository / wiki etc.
vmmctl_online_base_url='https://github.com/c-hartmann/vmmctl.sh'
#vmmctl_github_zip_url="${vmmctl_online_base}/archive/refs/heads/main.zip"

# https://www.tecmint.com/kde-based-linux-distributions/
# https://kde.org/de/distributions/
# Kubuntu 20 hat kein git an Bord, aber wget, curl auch nicht

# how to check with git on updates in remote repository

# found in: /usr/bin/xdg-email
check_output_file()
{
    # if the file exists, check if it is writeable
    # if it does not exists, check if we are allowed to write on the directory
    if [ -e "$1" ]; then
        if [ ! -w "$1" ]; then
            exit_failure_file_permission_write "no permission to write to file '$1'"
        fi
    else
        DIR=`dirname "$1"`
        if [ ! -w "$DIR" ] || [ ! -x "$DIR" ]; then
            exit_failure_file_permission_write "no permission to create file '$1'"
        fi
    fi
}


_get_console_path_path ()
{
}

_get_plasma_path_path ()
{
}

_add_console_path_to_plasma_path ()
{
}

_install_from_github ()
{
	_into="$1" # local directory to extract zip file
	_from="$2" # remote git address
}

_install_from_zip ()
{
	_into="$1" # local directory to extract zip file
	_from="$2" # full path of downloaded zip archive
}

_user_install ()
{
	_online_base_url="$1"

	# inform the user about what is going to happen next
	# (offer to visit the git page before install to build trust)

	# try (in this order): git > wget > curl

	_git_clone_base="${vmmctl_online_base_url}.git"
	_no_git_asset_zip="${vmmctl_online_base_url}/archive/refs/heads/main.zip"

	# create link to script
}

echo "check existence, completeness and version of vmmctl installed"
echo "if all requirements are satisfied, hand control over to vmmctl..."

# check if we have git. is there any distro not having it after base install? > yes, Kubuntu!
git_cmd_path="$(type -p git)"

#set -x
vmmctl_cmd_name='vmmctl'
vmmctl_cmd_path="$(type -p ${vmmctl_cmd_name})"

# to allow the use of vmmctl command without its full path,
# create or edit $HOME/.config/plasma-workspace/env/path.sh
# see: https://userbase.kde.org/Session_Environment_Variables

if [[ -z "$vmmctl_cmd_path" ]]; then
	echo "error: $vmmctl_cmd_name is not found or not installed"
	_user_install "$vmmctl_online_base_url"
else
	echo "found: $vmmctl_cmd_path"
fi

# exec # ?
${vmmctl_cmd_path} "$@"


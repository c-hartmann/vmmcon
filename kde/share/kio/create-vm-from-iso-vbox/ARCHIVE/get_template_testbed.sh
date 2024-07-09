#!/bin/bash

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

### me myself and i
MY_NAME=CreateVBoxVMfromISO # TODO swap to CreateVMfromISOVBox

### set some defaults so we do not fail on using these later
typeset -l template=""

### my installation directory
### Kudos for that:
### https://stackoverflow.com/questions/59895/how-can-i-get-the-source-directory-of-a-bash-script-from-within-the-script-itsel
### (this also has a more complex solution for tricky environments)
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
if [[ ! -d "$SCRIPT_DIR" ]]; then
	_error_exit "not found SCRIPT_DIR: $SCRIPT_DIR"
fi

### this is based on the idea of vm templates and this is where they live
TEMPLATES_DIR="${SCRIPT_DIR}/${MY_NAME}.d/templates.d"
TEMPLATES_DIR_LOCAL="${SCRIPT_DIR}/${MY_NAME}.d/templates.local.d"

### if no templete given and auto false we ask the userin for a template
#set -x
if [[ -z "$template" ]]; then
	### build up a list of available templates
	declare -A template_select_list
	for conf in "${TEMPLATES_DIR}"/*.conf "${TEMPLATES_DIR_LOCAL}"/*.conf; do
		name="UNKNOWN"
		. "$conf"
		# get simple tag from path to config file
		tag="${conf%.conf}"
		tag="${tag##*/}"
# 		echo \$tag=$tag
		### add to Array if not already in
		if [[ ! -v template_select_list[$tag] ]]; then
			template_select_list[${tag}]="$name"
 		fi
#  		echo ${template_select_list[*]}
	done
	# TODO build command arguments from Array
	kdialog_radiolist_tag_item_list=" "
# 	space=" "
	for tag in ${!template_select_list[*]}; do
		kdialog_radiolist_tag_item_list+="$tag ${template_select_list[$tag]} off "
	done
	### ask user what template to use or cancel
# 	echo \$kdialog_radiolist_tag_item_list=$kdialog_radiolist_tag_item_list
 	template=$(kdialog --title "$MY_NAME" --radiolist "Select template  to use:" $kdialog_radiolist_tag_item_list)
 	echo $template
fi

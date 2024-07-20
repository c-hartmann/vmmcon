# ex: filetype=sh
# file: /etc/bash_completion/vmmcon
#   or: ~/.bash_completion.d/vmmcon
# NOTE: command refers to a command of vmmcon as in: vmmcon <vmmcon_option> <command> <command_option> <vm_name> <vm_name>
# samples: ...
# /usr/share/bash-completion/completions/
# /usr/share/bash-completion/completions/gdbus



# function to create to create an array of vm names
_vmmcon_vm_list()
{
# 	local vm="$1" # NOTE: vm handled via $current_word in _vmmcon
#   vmmcon 'list' "$current_word" 2>/dev/null | tail +2
	local _vms=()
	#while read vm; do vms+=("$vm"); done < <( vmmcon 'list' "$vm" 2>/dev/null | grep -v '^$' )
	while read vm; do
# 		printf "::: %s\n" "${vm}" 1>&2
		_vms+=("$vm")
	done < <( vmmcon 'list' 2>/dev/null | grep -v '^$' )
	#COMPREPLY=( $( compgen -W "${vms[@]}" -- $current_word ) )
	#COMPREPLY=( "${vms[@]}" )
# 	printf "::: %s\n" "${_vms[@]}" 1>&2
	echo "${_vms[@]}" 1>&2
	printf "${_vms[@]}"
}

# function to create a list of commands without 'commands' (or other "secret" ones)
_vmmcon_commands()
{
	vmmcon 'commands' 2>/dev/null | sed 's/commands//'
}

# function to create command (see above) or vm names completions
# TODO: create a second vm name for commands as clone
_vmmcon()
{
	local current_word previous_word

	# init the reply array read by the bash to present completions
	COMPREPLY=()

	# word at (under) current cursor position
	current_word="${COMP_WORDS[COMP_CWORD]}"

	# previous word (before current word)
	previous_word="${COMP_WORDS[COMP_CWORD-1]}"

	# no (vmmcon) command given so far
	if [[ $COMP_CWORD -eq 1 ]] ; then
#		COMPREPLY=( $( compgen -W "create launch list start status" -- $current_word ) )  # just a sample
#		COMPREPLY=( $( compgen -W "$( vmmcon 'commands' 2>/dev/null )" -- $current_word ) )
		COMPREPLY=( $( compgen -W "$( _vmmcon_commands )" -- $current_word ) )
	else
			case $previous_word in
				clone | close | delete | destroy | enter | exec | export | halt \
				      | info | list | login | move | open | pause | poweroff | reboot \
				      | remove | rename | reset | restart | run | shell | shutdown \
				      | snap | ssh | start | state | status | stop | ungroup  | up | view \
				      )
					#_vmmcon_list
# 					COMPREPLY=( ein zwei drei )
# 					COMPREPLY=( $( compgen -W "$( _vmmcon_vm_list "$current_word" )" -- $current_word ) )
# 					COMPREPLY=( $( compgen -W "$( _vmmcon_vm_list )" -- $current_word ) )

# 					local _vms=()
# 					while read vm; do
# 						_vms+=("$vm")
# 					done < <( vmmcon 'list' 2>/dev/null | grep -v '^$' )

# 					echo 1>&2
#  					printf " '%s'" "${_vms[@]}" | sed 's/^ //' 1>&2
#  					printf '%q' "${_vms[@]}" 1>&2
#  					printf "\nmatching: '%s'\n" "${current_word}" 1>&2
# 					COMPREPLY=( $( compgen -W "${_vms[@]}" -- $current_word ) ) # TODO: ${_vms[@]} or ${_vms[*]} ? _vms[@]} as it is treating the array elements individualy to the printf statement
# 					COMPREPLY=( $(compgen -W $( printf " '%s'" "${_vms[@]}" | sed 's/^ //' ) -- "${current_word}") )
# 					WORD_LIST=
# 					printf '%q ' "${_vms[@]}" 1>&2
#  					printf " '%s'" "${_vms[@]}" | sed 's/^ //' 1>&2
# 					echo '-' 1>&2
#  					printf " '%s' " "${_vms[@]}" 1>&2
# 					echo 1>&2
					# NOTE: the word list has to enclosed in " itself. (it is *one* argument only)
#  					compgen -W "$(printf "%q " "${_vms[@]}")" -- "${current_word}" 1>&2
# 					set -x
# 					COMPREPLY=( $( compgen -W "$(printf "%q " "${_vms[@]}")" -- "${current_word}" ) )

# 					# NOTE: when building the array just from printing non quoted spaces are equaly treated to newlines
# 					while read line; do
# 						COMPREPLY+=("${line}")
# 					done < <(compgen -W "$(printf "%q " "${_vms[@]}")" -- "${current_word}")
					
					# TODO: there is basically no need here to make use of comgen[1], 
					#       as vmmlist 'list' <pattern> already creates the correct 
					#       newline separated list of vm names!
					local _vm
# 					printf '\n' 1>&2
					while read _vm; do
# 						printf '%s\n' "${_vm}" 1>&2
						COMPREPLY+=( "$(printf '%q' "${_vm}")" )
					done < <( vmmcon 'list' 2>/dev/null | grep -v '^$' | grep "^${current_word}" )
# 					printf '\nmatching vm count: %s\n' "${#COMPREPLY[@]}" 1>&2
					;;
			esac

			# TODO command options, such as --desktop
			#COMPREPLY=( $( compgen -W "$options" -- $current_word ) )
	fi

}
# main (connect autocompletion with function here)
complete -F _vmmcon vmmcon
complete -F _vmmcon hypcon
complete -F _vmmcon hypercon
complete -F _vmmcon hopper

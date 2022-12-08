#!/bin/sh

get_msg_i3_genconf() { 
	# _message determines which feedback message to call.
	# Just call "none" in the case you want no message to match.
	# _pass_cmd is optional, and can be used to exit and/or show usage

	local _message
	local _pass_cmd
	_message="$1"
	_pass_cmd="$2"

	case "$_message" in
	_1) cat << ENDOFMSG

ERROR: < $FILE > does not exist
ENDOFMSG
	;;	
	_2) cat << ENDOFMSG
##  I3GEN AUTO GENERATED MODES  ##
##  Edit i3gen.conf and run qb-i3-genconf to change/replace  ##

##  FIRST LEVEL BINDING MODE  ##

$JSELECT

ENDOFMSG
	;;	
	_3) cat << ENDOFMSG
mode "${_mode}" {
ENDOFMSG
	;;	
	_4) cat << ENDOFMSG
	bindsym $_sym $_action
ENDOFMSG
	;;	
	_5) cat << ENDOFMSG
	bindsym Return mode "default"
	bindsym Escape mode "default"
}

ENDOFMSG
	;;	
	_6) cat << ENDOFMSG

Config test successful. Saved new config over the old one.
ENDOFMSG
	;;
	_7) cat << ENDOFMSG
i3 reloaded successfully.

ENDOFMSG
	;;	
	_8) cat << ENDOFMSG
New i3 config was successfully reloaded.

ENDOFMSG
	;;	
	_9) cat << ENDOFMSG
If then new config did not take affect, either
manually reload, or you might need to restart i3.
  (Sometimes socket connections become corrupted).

ENDOFMSG
	;;	
	_10) cat << ENDOFMSG

ERROR: The new config has errors, and was not loaded. 
       It was saved to the following location: 
       ${HOME}/.config/i3/config_attempted

ENDOFMSG
	;;
	esac

	case $_pass_cmd in 
		usage_0) usage ; exit 0 ;;
		usage_1) usage ; exit 1 ;;
		exit_0)  exit 0 ;;
		exit_1)  exit 1 ;;
		*) : ;;
	esac
}

usage() { cat << ENDOFUSAGE

qb-i3-genconf: Adds keybindings to the i3 config, as
               indicated by a separate i3gen (setup) file.

With dozens of jails and programs, the combination of
keybindings can become unwieldy to manage manually. This 
program generates combinations automatically on the basis
of a simple i3gen.conf, and adds them to the i3 config. 

Usage: qb-i3-genconf [-c <conf_file>][-h][-f <conf_file>]
   -c: (c)onfig. Add bindsyms to alternate i3 config file.
       Default is: ${HOME}/.config/i3/config 
   -d: (d)o not reload after completion. Default behavior
       is to sanity check the config, and reload.
   -h: (h)elp. Outputs this help message.
   -f: (file). Run an alternate setup file. Default i3gen
       setup is: < ${HOME}/.config/i3/i3gen.conf >

ENDOFUSAGE
}


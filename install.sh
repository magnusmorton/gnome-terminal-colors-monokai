#!/usr/bin/env bash

## Change this to change the color scheme.

# Color scheme borrowed from sublime-monokai-extended
# (https://github.com/jonschlinkert/sublime-monokai-extended)
#COLOR="extended"

# The default color scheme.
COLOR="default"

dir=$(dirname $0)

dconfdir=/org/gnome/terminal/legacy/profiles:


declare -a profiles
profiles=($(dconf list $dconfdir/ | grep ^: | sed 's/\///g'))

die() {
  echo $1
  exit ${2:-1}
}

in_array() {
  local e
  for e in "${@:2}"; do [[ $e == $1 ]] && return 0; done
  return 1
}

show_help() {
  echo
  echo "Usage"
  echo
  echo "    install.sh [-h|--help] \\"
  echo "               (-p <profile>|--profile <profile>|--profile=<profile>)"
  echo
  echo "Options"
  echo
  echo "    -h, --help"
  echo "        Show this information"
  echo "    -p, --profile"
  echo "        Gnome Terminal profile to overwrite"
  echo
}

createNewProfile() {
  # b1dcc9dd-5262-4d8d-a863-c897e6d979b9 is totally abitrary, I took my
  # profile id
  profile_id="b1dcc9dd-5262-4d8d-a863-c897e6d979b9"
  dconf write $dconfdir/default "'$profile_id'"
  dconf write $dconfdir/list "['$profile_id']"
  profile_dir="$dconfdir/:$profile_id"
  dconf write $profile_dir/visible-name "'Default'"
}

validate_profile() {
  local profile=$1
  in_array $profile "${profiles[@]}" || die "$profile is not a valid profile" 3
}

get_profile_name() {
  local profile_name

  # dconf still return "" when the key does not exist, gconftool-2 return 0,
  # but it does priint error message to STDERR, and command substitution
  # only gets STDOUT which means nothing at this point.
  profile_name=$(dconf read $dconfdir/$1/visible-name)
  [[ -z $profile_name ]] && die "$1 is not a valid profile" 3
  echo $profile_name
}

set_profile_colors() {
  local profile=$1

  local bg_color_file=$dir/$COLOR/bg_color
  local fg_color_file=$dir/$COLOR/fg_color
  local bd_color_file=$dir/$COLOR/bd_color

  local profile_path=$dconfdir/$profile

  # set color palette
  dconf write $profile_path/palette "['$(cat $dir/$COLOR/palette)']"

  # set foreground, background and highlight color
  dconf write $profile_path/bold-color "'$(cat $bd_color_file)'"
  dconf write $profile_path/background-color "'$(cat $bg_color_file)'"
  dconf write $profile_path/foreground-color "'$(cat $fg_color_file)'"

  # make sure the profile is set to not use theme colors
  dconf write $profile_path/use-theme-colors "false"

  # set highlighted color to be different from foreground color
  dconf write $profile_path/bold-color-same-as-fg "false"

}

interactive_help() {
  echo
  echo "This script will ask you which Gnome Terminal profile to overwrite."
  echo
  echo "Please note that there is no uninstall option yet. If you do not wish"
  echo "to overwrite any of your profiles, you should create a new profile"
  echo "before you run this script. However, you can reset your colors to the"
  echo "Gnome default, by running:"
  echo
  echo "    Gnome >= 3.8 dconf reset -f /org/gnome/terminal/legacy/profiles:/"
  echo "    Gnome < 3.8 gconftool-2 --recursive-unset /apps/gnome-terminal"
  echo
  echo "By default, it runs in the interactive mode, but it also can be run"
  echo "non-interactively, just feed it with the necessary options, see"
  echo "'install.sh --help' for details."
  echo
}

interactive_new_profile() {
  local confirmation

  echo    "No profile found"
  echo    "You need to create a new default profile to continue. Continue ?"
  echo -n "(YES to continue) "

  read confirmation
  if [[ $(echo $confirmation | tr '[:lower:]' '[:upper:]') != YES ]]
  then
    die "ERROR: Confirmation failed -- ABORTING!"
  fi

  echo -e "Profile \"Default\" created\n"
}

check_empty_profile() {
  if [ "$profiles" = "" ]
    then interactive_new_profile
    createNewProfile
    profiles=($(dconf list $dconfdir/ | grep ^: | sed 's/\///g'))
  fi
}

interactive_select_profile() {
  local profile_key
  local profile_name
  local profile_names
  local profile_count=$#

  declare -a profile_names
  while [ $# -gt 0 ]
  do
    profile_names[$(($profile_count - $#))]=$(get_profile_name $1)
    shift
  done

  set -- "${profile_names[@]}"

  echo "Please select a Gnome Terminal profile:"
  select profile_name
  do
    if [[ -z $profile_name ]]
    then
      die "ERROR: Invalid selection -- ABORTING!" 3
    fi
    profile_key=$(expr ${REPLY} - 1)
    break
  done
  echo

  profile=${profiles[$profile_key]}
}

interactive_confirm() {
  local confirmation

  echo    "You have selected:"
  echo
  echo    "  Profile: $(get_profile_name $profile) ($profile)"
  echo
  echo    "Are you sure you want to overwrite the selected profile?"
  echo -n "(YES to continue) "

  read confirmation
  if [[ $(echo $confirmation | tr '[:lower:]' '[:upper:]') != YES ]]
  then
    die "ERROR: Confirmation failed -- ABORTING!"
  fi

  echo    "Confirmation received -- applying settings"
}

while [ $# -gt 0 ]
do
  case $1 in
    -h | --help )
      show_help
      exit 0
    ;;
    --profile=* )
      profile=${1#*=}
    ;;
    -p | --profile )
      profile=$2
      shift
    ;;
  esac
  shift
done

if [[ -z $profile ]]
then
  interactive_help
  check_empty_profile
  interactive_select_profile "${profiles[@]}"
  interactive_confirm
fi

if [[ -n $profile ]]
then
  validate_profile $profile
  set_profile_colors $profile
fi

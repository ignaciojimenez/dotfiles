#!/bin/bash

programname=$0

# usage function
function usage {
    echo "usage: $programname [--kickstart | -k]"
    echo "  --kickstart | -k      installs the environment packages. Intended for new installations"
    exit 1
}

# detecting command line input
case "$1" in
  "--kickstart" | "-k")
    echo "Setting up dotfiles and kickstarting the environment"
    kickstart=1
    ;;
  "")
    echo "Setting up only dotfiles"
    kickstart=0
    ;;
  *)
    usage
    exit 1
    ;;
esac

# importing common functions
source thefiles/.common_functions

# detecting os type
os_type=$(detect_os)
if [ "$os_type" != "unix" ] && [ "$os_type" != "macos" ]; then
  echo "Unexpected/not supported \$OSTYPE=$OSTYPE. Exiting..."
  exit 1
fi

# maintaining dotfiles with symlinks
echo "Creating symlinks to dotfiles in \$HOME folder"
ignore_list=".idea .git .gitignore . .. .DS_Store"
for file_path in thefiles/.*; do
  filename=$(basename "$file_path")
  # exclude ignore_list from symlinking
  ignore=$(list_include_item "${ignore_list}" "${filename}")
  if [ "$ignore" -eq 0 ]; then
    # if dotfile already exists we store a backup file
    if test -f "$HOME/$filename" || test -d "$HOME/$filename" ; then
      echo "${HOME}/${filename} exists, storing backup in ${HOME}/${filename}_bkp"
      mv "$HOME/$filename" "$HOME/$filename"_bkp
    fi
    # create a symlink for the dotfile
    ln -sv "$PWD/$file_path" "$HOME"
  fi
done

# if the system needs to be kickstarted
# Opening kickstart script
if [[ "$kickstart" -eq 1 ]]; then
  source env_bootstrap "$os_type"
fi
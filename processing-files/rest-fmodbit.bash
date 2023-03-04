#!/bin/bash

# shellcheck disable=SC2012

#
# Platform: Tested on Ubuntu Server 22.04. Adjust it according to your needs.
#
# Requeriments: It must be run as root because it makes changes to sensitive files.
#
# Purpose: This script can be used to reset the file mode bits of
# executables located in /bin -> /usr/bin, if you have changed them by mistake.
# It is necessary that they have the indicated bits for their correct operation.
#
# Warning: Making changes is not recommended unless you know what you're doing,
# as the commands inside the arrays below were included as case exclusive and
# need to have the setuid/setgid bits. The most important is the "sudo" command,
# it must be executed with root id (0).

if ! [ "$(id -u)" = 0 ]; then

  echo "Are you Superuser!?..."
  echo "Please try again using the sudo command."
  exit 0

fi

# path to executables
bins="/usr/bin/"

# common bits that are assigned to executables.
# This is the same as chmod u+rwx,go+rx [file].
cmmon=0755

# World readable bits.
# This is the same as chmod u+rwx [file].
wo_re=0777

# Common bits plus setuid.
# This is the same as chmod u+rws,go+rx [file].
suid=4755

# Common bits plus setgid.
# This is the same as chmod u+rwx,go+rx,g+s [file].
sgid=2755

# World readable bits plus setuid.
# This is the same as chmod a+rwx,u+s [file].
wr_suid=4777

# World readable bits plus setgid.
# This is the same as chmod a+rwx,g+s [file].
wr_sgid=2777

# Array of commands that MUST HAVE the setuid
# bit to be executed
suid_cmds=(
  at
  chsh
  chfn
  fusermount
  gpasswd
  mount
  newgrp
  passwd
  pkexec
  su
  sudo
  sudoedit
  umount
)

# Array of commands that MUST HAVE the setgid
# bit to be executed
sgid_cmmds=(
  write
  wall
  expiry
  crontab
  chage
  bsd-write
  ssh-agent
)

# Iterates over the contents of the directory
for cm in "$bins"*; do

  # Ignore directories to avoid changing file mode bits
  if ! [ -d "$cm" ]; then

    # Exctract just the command name
    cmd="$(echo "$cm" | cut -d/ -f4)"
    filepath="$cm"

    # Set to true if this is a command
    # that must have setgid or setuid modes
    is_setid=false

    # "Empty" variable to which the file mode
    # is assigned depending on what mode it currently has
    setbit=true

    # Extract just the file mode
    bits="$(ls -la "$filepath" | cut -d' ' -f1)"
    echo "bits: $bits"

    # sets the file mode bit to the `setbit` variable
    case "$bits" in
    *rwxrwxrwx*)
      setbit="$wo_re"
      ;;
    *rwsr-xr-x*)
      setbit="$cmmon"
      ;;
    *)
      setbit="$cmmon"
      ;;
    esac

    echo -e "permission bit: $setbit \c"

    # Iterates over setgid commands
    # and changes its file mode bit.
    for sgidcmd in "${sgid_cmmds[@]}"; do

      if [ "$cmd" == "$sgidcmd" ]; then
        is_setid=true

        if ((setbit == wo_re)); then
          echo "to permission bit: $wr_sgid"
          echo -e "setgid world readable command $sgidcmd\n"
          chmod "$wr_sgid" "$cm" >&1

        else
          echo "to permission bit: $sgid"
          echo -e "setgid command $sgidcmd\n"
          chmod "$sgid" "$cm" >&1

        fi

      fi
    done

    # Iterates over setuid commands
    # and changes its file mode bit.
    for suicmd in "${suid_cmds[@]}"; do

      if [ "$cmd" == "$suicmd" ]; then
        is_setid=true

        if ((setbit == wo_re)); then
          echo "to permission bit: $wr_suid"
          echo -e "setuid world readable command: $cmd\n"
          chmod "$wr_suid" "$cm" >&1

        else
          echo "to permission bit: $suid"
          echo -e "setuid command: $cmd\n"
          chmod "$suid" "$cm" >&1

        fi

      fi
    done

    # Any other command that doesn't
    # need setuid or setgid bit.
    if [ "$is_setid" == false ]; then
      if ((setbit == wo_re)); then
        echo "to permission bit: $wo_re"
        echo -e "world readable command: $cmd\n"
        chmod "$wo_re" "$cm" >&1

      else
        echo "to permission bit: $cmmon"
        echo -e "command: $cmd\n"
        chmod "$cmmon" "$cm" >&1

      fi

    fi

    unset is_setid
  # sleep 1

  fi

done

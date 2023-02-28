#!/usr/bin/env bash

#
# You can use this script to check if the command
# of each completion in /usr/share/bash-completion/completions
# exists.
#
# For example:
#
# If you want to copy completions from somewhere to the completions dir,
# you can check if all completions for the commands to be added,
# are installed and filter out those that are not.
#

# Path to bash completions.
# ** On Ubuntu this normally is in ´/usr/share/bash-completion/´
# ** On MacOs this normally is in ´/usr/local/etc/bash_completion (script) | bash_completion.d/ (completions)´
bash_completions=/usr/local/etc/bash_completion.d

# Path from where completions will be added
completions_source="$1"
commands=()
existent_cmds=()
count=0

# Iterates each of the files in the source path and
# creates an array of the completions to be added.
for f in "$completions_source"/*; do
  if ! [ -d "$f" ]; then
    commands+=("$f")
  fi
done

echo "Number of completions: ${#commands[@]}"

# For each completion from the source path,
# the command ´command´ is used to check if
# the command for the completion to be added
# exists.
for f in "${commands[@]}"; do

  # We just need the name of the command
  cmd="$(echo "$f" | cut -d'/' -f 7)"

  # If the command is already installed,
  # its path is added to an array.
  if [ "$(command -v "$cmd")" ]; then
    echo "command $cmd found."
    existent_cmds+=("$f")
  fi

  until ((count == ${#commands[@]})); do
    ((count = count + 1))
    ((count == ${#commands[@]})) && break
  done
done

# For each new completion, checks if it doesn't
# exist in the bash-completion dir....
for path in "${existent_cmds[@]}"; do

  # Again we just need the command name
  newcmd="$(echo "$path" | cut -d'/' -f 7)"

  # ....and if doesn't exist, is added.
  if ! [ -f "$path" ]; then
    echo -e "\ncompletion for the command $newcmd will be added"
    cp "$path" "$bash_completions" ||
      echo "$newcmd" >>/Users/danielcrespo/leftcompletions
  fi
done

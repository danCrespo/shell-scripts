#!/usr/bin/env bash

path_to_files="$1"
search_word="$2"
counter=0
files=()
words=()

# adds all files in the path to the array,
# this way you can use the length of the
# array or process the files.
for f in "$path_to_files"/*; do

  if ! [ -d "$f" ]; then
    files+=("$f")
  fi

done

for f in "$path_to_files"/*; do
  while read line; do
    for word in $line; do
      # If a word within any file matches
      # the searched word, you can do anything
      if [ "$word" == "$search_word" ]; then
        echo "Word $search_word found in $f"

        # add each matched word to the array
        # for lately process it
        words+=("$word")

        # Do something with the file ($f), or
        # do something with the match word ($word)
      fi

    done
  done <"$f"

  until ((counter == ${#files[@]})); do
    ((counter = counter + 1))

    ((counter == ${#files[@]})) && break
  done
done

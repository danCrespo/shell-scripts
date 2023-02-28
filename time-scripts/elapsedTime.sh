#!/usr/bin/env bash

# Purpose: Takes the number of seconds from the input
#          and produces as output the time represented
#          in hours, minutes and seconds.

elapsed_time() {

  sec="$1"

  ((sec < 60)) && echo -e "[Elapsed time: $sec seconds]\c"

  ((sec >= 60 && sec < 3600)) && echo -e "[Elapsed time: $((sec / 60)) \
  min $((sec % 60)) sec]\c"

  ((sec > 3600)) && echo -e "[Elapsed time: $((sec / 3600)) hr \
  $(((sec % 3600) / 60)) min $(((sec % 3600) % 60)) sec] \c"

  exit 0
}

elapsed_time "$1"

#!/usr/bin/env bash

# Purpose: Merge process for fixed-length record files

merger_record_file=/data/mergerecord.$(date +%m%d%y)
record_file_list=/data/branch_records.lst
FD=:

while read record_file_name; do

  sed s/$/${FD}"$(basename "$record_file_name")" /g \
    "$record_file_name" >>"$merger_record_file"

done <"$record_file_list"

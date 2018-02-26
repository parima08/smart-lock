#!/bin/sh
# Create/add to the set of models visible in ActiveAdmin.
# Run from src/server server source root.

for m in `ls app/models/*.rb`
do
  rails generate active_admin:resource `fgrep class $m|fgrep ActiveRecord|sed -e "s/.*class//" -e 's/<.*//'`
done

#!/usr/bin/env bash

log='/var/egotter/log/cron.log'
cmd="/usr/local/bin/bundle exec rake $1"

echo "`date` $cmd started" >>$log 2>&1
cd /var/egotter && RAILS_ENV=production $cmd >>$log 2>&1
echo "`date` $cmd finished" >>$log 2>&1
#!/usr/bin/env bash

CMD="cd /var/egotter && git pull origin master && bundle install --path .bundle --without test development && RAILS_ENV=production bundle exec rake assets:precompile && sudo service puma restart"

for i in $(seq 3 8); do
  ssh egotter_web${i} "$CMD"

  sleep 30
done

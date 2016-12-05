#!/bin/sh

# Let's make sure we abort if anything breaks
set -e

# This thing depends on RVM
rvm install `cat .ruby-version`

# Just in case build.sh installed a ruby above, etc
# the internet thinks this might help cause us to reload.
rvm use .

gem install bundler
bundle install

bundle exec warble compiled jar

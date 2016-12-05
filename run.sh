#!/bin/sh

# Just in case build.sh installed a ruby above, etc
# the internet thinks this might help cause us to reload.
rvm use .

bundle exec jruby -I lib bin/run generate "$1" "$1.index"
bundle exec jruby -I lib bin/run serve "$1" "$1.index"

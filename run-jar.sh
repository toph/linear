#!/bin/sh
java -jar linear.jar generate "$1" "$1.index"
java -jar linear.jar serve "$1" "$1.index"



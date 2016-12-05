#!/bin/bash

if [ ! -d .bundles ]; then
	echo "Creating directory for bundles..."
	mkdir .bundles
fi

export BUNDLE_PATH=`realpath .bundles`
echo "BUNDLE_PATH is now set to $BUNDLE_PATH"


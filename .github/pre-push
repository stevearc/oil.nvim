#!/bin/bash
set -e
IFS=' '
while read local_ref _local_sha _remote_ref _remote_sha; do
	remote_main=$( (git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null || echo "///master") | cut -f 4 -d / | tr -d "[:space:]")
	local_ref_short=$(echo "$local_ref" | cut -f 3 -d / | tr -d "[:space:]")
	if [ "$local_ref_short" = "$remote_main" ]; then
		make lint
		make test
	fi
done

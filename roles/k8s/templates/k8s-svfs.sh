#!/bin/bash

# Copyright 2015 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source /etc/kubernetes/cloud-config.sh

# Notes:
#  - Please install "jq" package before using this driver.
usage() {
	err "Invalid usage. Usage: "
	err "\t$0 init"
	err "\t$0 mount <mount dir> <json params>"
	err "\t$0 unmount <mount dir>"
	exit 1
}

err() {
	echo -ne $* 1>&2
}

log() {
	echo -ne $* >&1
}

ismounted() {
	MOUNT=`findmnt -n ${MNTPATH} 2>/dev/null | cut -d' ' -f1`
	if [ "${MOUNT}" == "${MNTPATH}" ]; then
		echo "1"
	else
		echo "0"
	fi
}

domount() {
	MNTPATH=$1
	CONTAINER=$(echo $2 | jq -r '.container')

	if [ $(ismounted) -eq 1 ]; then
		log '{"status": "Success"}'
		exit 0
	fi

	mkdir -p ${MNTPATH} &> /dev/null
	mount -t svfs -o container=${CONTAINER},allow_other,attr,xattr,mode=0777 svfs-${CONTAINER} ${MNTPATH} &> /dev/null
	if [ $? -ne 0 ]; then
		err "{ \"status\": \"Failure\", \"message\": \"Failed to mount ${CONTAINER} at ${MNTPATH}\"}"
		exit 1
	fi
	log '{"status": "Success"}'
	exit 0
}

unmount() {
	MNTPATH=$1
	if [ $(ismounted) -eq 0 ] ; then
		log '{"status": "Success"}'
		exit 0
	fi

	umount ${MNTPATH} &> /dev/null
	if [ $? -ne 0 ]; then
		err "{ \"status\": \"Failed\", \"message\": \"Failed to unmount volume at ${MNTPATH}\"}"
		exit 1
	fi

	log '{"status": "Success"}'
	exit 0
}

op=$1

if ! command -v jq >/dev/null 2>&1; then
	err "{ \"status\": \"Failure\", \"message\": \"'jq' binary not found. Please install jq package before using this driver\"}"
	exit 1
fi

if [ "$op" = "init" ]; then
	log '{"status": "Success", "capabilities": {"attach": false}}'
	exit 0
fi

if [ $# -lt 2 ]; then
	usage
fi

shift

case "$op" in
	mount)
		domount $*
		;;
	unmount)
		unmount $*
		;;
	*)
		log '{"status": "Not supported"}'
		exit 0
esac

exit 1

#!/bin/bash

if [ "$1X" == "X" -o "$2X" == "X" ]
then
	echo "usage: $0 private-key ec2-FQDN"
	exit 1
fi

private_key=${1}
ec2_fqdn=${2}

ssh -i ${private_key} "ec2-user@${ec2_fqdn}"

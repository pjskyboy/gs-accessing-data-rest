#!/bin/bash

if [ "$1X" == "X" -o "$2X" == "X" ]
then
    echo "usage : $0 ec2-id desired-state"
    exit 1
fi

id=${1}
desired=${2}
echo -n "waiting for instance [${id}] to change state from [${desired}]"
while state=$(aws ec2 describe-instances --instance-ids ${id} --output text --query 'Reservations[*].Instances[*].State.Name'); [ "${state}" == "${desired}" ]
do
    echo -n .
    sleep 3
done
echo " [${state}]"
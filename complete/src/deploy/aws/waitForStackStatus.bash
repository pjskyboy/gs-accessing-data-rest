#!/bin/bash

usage() { echo "Usage: $0 -s stackName -d desiredStatus" 1>&2; exit 1; }

stackName=""
desiredStatus=""

while getopts ":s:d:" o; do
    case "${o}" in
        s)
            stackName=${OPTARG}
            ;;
        d)
            desiredStatus=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${stackName}" ] || [ -z "${desiredStatus}" ]; then
    usage
fi

echo "stackName [${stackName}] desiredStatus [${desiredStatus}]"

result=0
while currentState=$(aws cloudformation describe-stacks --stack-name ${stackName} --output text --query 'Stacks[*].StackStatus'); [ $? == 0 ] && [ "${currentState}" != "${desiredStatus}" ]
do
    if [ ${currentState} == "ROLLBACK*" ] && [ ${desiredStatus} != "DELETE_COMPLETE" ]
    then
        echo "[${stackName}] in a ROLLBACK state - stopping wait"
        result=100
        break
    fi
    echo -n .
    sleep 2
done

echo "stackName [${stackName}] currentState [${currentState}]"
exit ${result}
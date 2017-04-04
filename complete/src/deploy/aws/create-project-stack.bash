#!/bin/bash

usage() { echo "Usage: $0 -p project -a azRoot -k publicKeyname [-f yaml_filenames] [-u cluster-username] [-c cluster-password] [-j jdbcUrl]" 1>&2; exit 1; }

project=""
azRoot=""
publicKeyname=""
fileList="network.yml rds.yml ec2.yml"
username="ec2appdbo"
credential=""
jdbcUrl="missing"

while getopts ":p:a:k:f:u:c:j:" o; do
    case "${o}" in
        j)
            jdbcUrl=${OPTARG}
            ;;
        u)
            username=${OPTARG}
            ;;
        c)
            credential=${OPTARG}
            ;;
        p)
            project=${OPTARG}
            ;;
        a)
            azRoot=${OPTARG}
            ;;
        k)
            publicKeyname=${OPTARG}
            ;;
        f)
            fileList=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${project}" ] || [ -z "${azRoot}" ] || [ -z "${publicKeyname}" ]; then
    usage
fi

echo "project [${project}]"
echo "azRoot [${azRoot}]"
echo "publicKeyname [${publicKeyname}]"
echo "fileList [${fileList}]"
echo "username [${username}]"
echo "credential [${credential}]"
echo "jdbcUrl [${jdbcUrl}]"

# eu-west-1 ami id
amiId="ami-2587b443"
ebsSnapshotId="snap-0853d33212ae1395d"

if [ "${azRoot}" == "eu-west-2" ]
then
    # eu-west-2 resources
    amiId="ami-0eacb96a"
#    ebsSnapshotId="snap-0261788f106d8e63a"
    echo "*** You need to replicate the ${ebsSnapshotId} to eu-west-2! ***"
    exit 200
fi

echo "amiId [${amiId}]"
echo "ebsSnapshotId [${ebsSnapshotId}]"

cp -v waitForStackStatus.bash ${project}
pushd ${project}

echo "Applying YAML in yaml.d..."
for yaml in ${fileList}
do
    stackName=`echo ${yaml} | cut -f 1 -d"."`
    stackName="${project}-${stackName}"
    echo "stackName [${stackName}]"

    parameterList=""
    case ${yaml} in
        "network.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=azRoot,ParameterValue=${azRoot} ParameterKey=domainName,ParameterValue=${azRoot}.compute.internal"
            ;;
        "ec2.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=networkStackName,ParameterValue=${project}-network ParameterKey=rdsStackName,ParameterValue=${project}-rds ParameterKey=amiId,ParameterValue=${amiId} ParameterKey=keyPair,ParameterValue=${publicKeyname} ParameterKey=ownerId,ParameterValue=751191391887 ParameterKey=ebsSnapshotId,ParameterValue=${ebsSnapshotId} ParameterKey=clusterUsername,ParameterValue=${username} ParameterKey=clusterPassword,ParameterValue=${credential}  ParameterKey=jdbcUrl,ParameterValue=${jdbcUrl}"
            ;;
        "rds.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=networkStackName,ParameterValue=${project}-network ParameterKey=azRoot,ParameterValue=${azRoot} ParameterKey=clusterUsername,ParameterValue=${username} ParameterKey=clusterPassword,ParameterValue=${credential}"
            ;;
    esac

    echo "yaml [${yaml}]"
    echo "parameterList [${parameterList}]"

    aws cloudformation create-stack --stack-name ${stackName} --template-body file://yaml.d/${yaml} --parameters ${parameterList}

    if [ ${yaml} == "rds.yml" ]
    then
        jdbcUrl=$(aws cloudformation describe-stacks --stack-name ${project}-rds --query 'Stacks[0].Outputs[?OutputKey==`clusterJDBCConnectionString`].OutputValue' --output text)
        echo "jdbcUrl [${jdbcUrl}]"
    fi

    if [ $? == 0 ]
    then
        ./waitForStackStatus.bash -s ${stackName} -d "CREATE_COMPLETE"
        result=$?
        if [ ${result} -ne 0 ]
        then
            echo "[$stackName}] create has failed - aborting project creation, please investigate and tidy up"
            exit 100
        fi
    else
        echo "Creation request failed"
    fi
done

echo "Execution completed"

popd

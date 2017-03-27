#!/bin/bash

usage() { echo "Usage: $0 -p project -a azRoot -k publicKeyname [-f yaml_filenames]" 1>&2; exit 1; }

project=""
azRoot=""
publicKeyname=""
fileList="network.yml ec2.yml"

while getopts ":p:a:k:f:" o; do
    case "${o}" in
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

# eu-west-1 ami id
amiId="ami-2587b443"
if [ "${azRoot}" == "eu-west-2" ]
then
    amiId="ami-0eacb96a"
fi
echo "amiId [${amiId}]"

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
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=azA,ParameterValue=${azRoot}a ParameterKey=azB,ParameterValue=${azRoot}b ParameterKey=domainName,ParameterValue=${azRoot}.compute.internal"
            ;;
        "loadbalancer.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=networkStackName,ParameterValue=${project}-network"
            ;;
        "ec2.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=networkStackName,ParameterValue=${project}-network ParameterKey=amiId,ParameterValue=${amiId} ParameterKey=keyPair,ParameterValue=${publicKeyname} ParameterKey=ownerId,ParameterValue=751191391887"
            ;;
    esac

    echo "yaml [${yaml}] parameterList [${parameterList}]"

    aws cloudformation create-stack --stack-name ${stackName} --template-body file://yaml.d/${yaml} --parameters ${parameterList}

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



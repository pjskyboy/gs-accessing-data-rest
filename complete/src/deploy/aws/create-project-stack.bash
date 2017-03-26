#!/bin/bash

usage() { echo "Usage: $0 -p project -a azRoot" 1>&2; exit 1; }

project=""
azRoot=""

while getopts ":p:a:" o; do
    case "${o}" in
        p)
            project=${OPTARG}
            ;;
        a)
            azRoot=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${project}" ] || [ -z "${azRoot}" ]; then
    usage
fi

echo "project [${project}] azRoot [${azRoot}]"

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
for yaml in network.yml loadbalancer.yml ec2.yml
do
    stackName=`echo ${yaml} | cut -f 1 -d"."`
    stackName="${project}-${stackName}"
    echo "stackName [${stackName}]"

    status=$(aws cloudformation describe-stacks --stack-name ${stackName} --output text --query 'Stacks[0].StackStatus')
    if [ $? -eq 0 ]
    then
        if [ ${status} == "CREATE_COMPLETE" ] || [ ${status} == "ROLLBACK_COMPLETE" ] || [ ${status} == "ROLLBACK__IN_PROGRESS" ]
        then
            echo "Removing stack for [${project}] yaml [${yaml}]..."
            aws cloudformation delete-stack --stack-name ${stackName}
            ./waitForStackStatus.bash -s ${stackName} -d "DELETE_COMPLETE"
        fi
    else
        echo "Assuming no stack for [${stackName}]"
    fi

    parameterList=""
    case ${yaml} in
        "network.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=azA,ParameterValue=${azRoot}a ParameterKey=azB,ParameterValue=${azRoot}b"
            ;;
        "loadbalancer.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=networkStackName,ParameterValue=${project}-network"
            ;;
        "ec2.yml")
            parameterList="ParameterKey=projectName,ParameterValue=${project} ParameterKey=networkStackName,ParameterValue=${project}-network ParameterKey=amiId,ParameterValue=ami-2587b443 ParameterKey=keyPair,ParameterValue=sundancer_id_rsa.pub ParameterKey=ownerId,ParameterValue=751191391887"
            ;;
    esac

    echo "yaml [${yaml}] parameterList [${parameterList}]"

    aws cloudformation create-stack --stack-name ${stackName} --template-body file://yaml.d/${yaml} --parameters ${parameterList}

    if [ $? == 0 ]
    then
        ./waitForStackStatus.bash -s ${stackName} -d "CREATE_COMPLETE"
    else
        echo "Creation request failed"
    fi
done

echo "Execution completed"

popd



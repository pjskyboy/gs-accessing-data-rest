#!/bin/bash

usage() { echo "Usage: $0 -p project [-f yaml_filenames]" 1>&2; exit 1; }

project=""
fileList="ec2.yml network.yml"

while getopts ":p:f:" o; do
    case "${o}" in
        p)
            project=${OPTARG}
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

if [ -z "${project}" ]; then
    usage
fi

echo "project [${project}]"
echo "fileList [${fileList}]"

cp -v waitForStackStatus.bash ${project}
pushd ${project}

echo "Applying YAML in yaml.d..."
for yaml in ${fileList}
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
done

echo "Execution completed"

popd
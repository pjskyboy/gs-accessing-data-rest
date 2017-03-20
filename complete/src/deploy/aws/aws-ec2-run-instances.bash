#!/bin/bash

if [ "$1X" == "X" ]
then
    echo "usage : $0 <project> "
    echo "project will be used to prefix all EC2 dependencies"
    exit 1
fi

project="${1}"
echo "project [$project]"

echo "Creating resources...."
aws ec2 create-key-pair --key-name ${project} --output text --query 'KeyMaterial' > ${project}/${project}.pem
chmod -v 600 ${project}/${project}.pem
echo "PEM file [{project}/${project}.pem]"

vpcId=$(aws ec2 create-vpc --cli-input-json file://${project}/create-vpc.json --output text --query 'Vpc.VpcId')
echo "vpcId [$vpcId]"

euWest2aSubnetId=$(aws ec2 create-subnet --vpc-id ${vpcId} --availability-zone eu-west-2a --cidr-block 172.31.0.0/20 --output text --query 'Subnet.SubnetId')
euWest2bSubnetId=$(aws ec2 create-subnet --vpc-id ${vpcId} --availability-zone eu-west-2b --cidr-block 172.31.16.0/20 --output text --query 'Subnet.SubnetId')
echo "euWest2aSubnetId [$euWest2aSubnetId] euWest2bSubnetId [$euWest2bSubnetId]"

echo "Complete"

echo "Generating removal script..."
removalScript="remove_${project}.bash"
echo "#!/bin/bash" > ${removalScript}
echo "" >> ${removalScript}

echo "aws ec2 delete-subnet --subnet-id ${euWest2aSubnetId}" >>  ${removalScript}
echo "aws ec2 delete-subnet --subnet-id ${euWest2bSubnetId}" >>  ${removalScript}
echo "aws ec2 delete-vpc --vpc-id ${vpcId}" >>  ${removalScript}
echo "aws ec2 delete-key-pair --key-name ${project}" >>  ${removalScript}
echo "script [${removalScript}]"

chmod -v 755 ${removalScript}

bash -x ${removalScript}

#aws ec2 run-instances --image-id ami-0eacb96a --key-name test-ec2-london-2 --security-group-ids sg-962d84ff sg-69fb5000 --user-data file://user-data.bash --instance-type t2.micro --placement AvailabilityZone=eu-west-2a,Tenancy=default
#aws ec2 run-instances --image-id ami-0eacb96a --key-name test-ec2-london-2 --security-group-ids sg-962d84ff sg-69fb5000 --user-data file://user-data.bash --instance-type t2.micro --placement AvailabilityZone=eu-west-2b,Tenancy=default

#aws ec2 run-instances --cli-input-json file://launch-candidate.json --security-group-ids sg-962d84ff sg-69fb5000
#!/bin/bash

if [ "$1X" == "X" -o "$2" == "X" ]
then
    echo "usage : $0 <project> az-root"
    echo "project will be used to prefix all EC2 dependencies"
    echo "az-root will be used with a,b,c e.g. eu-west-1"
    exit 1
fi

project="${1}"
azRoot="${2}"
echo "project [${project}] azRoot [${azRoot}]"

# eu-west-1 ami id
amiId="ami-2587b443"
if [ "${azRoot}" == "eu-west-2" ]
then
    amiId="ami-0eacb96a"
fi
echo "amiId [${amiId}]"

cp -v waitForInstance.bash ${project}
pushd ${project}

echo "Creating resources...."
aws ec2 create-key-pair --key-name ${project} --output text --query 'KeyMaterial' > ${project}.pem
chmod -v 600 ${project}.pem
echo "PEM file [${project}.pem]"

# to hold ids for tagging after creation
#
idArray=()

# VPC creation #
################

vpcId=$(aws ec2 create-vpc --cidr-block "172.31.0.0/16" --instance-tenancy "default" --output text --query 'Vpc.VpcId')
idArray+=(${vpcId})
echo "vpcId [${vpcId}]"

echo "Enabling DNS hostnames for [${vpcId}]"
aws ec2 modify-vpc-attribute --vpc-id ${vpcId} --enable-dns-support
aws ec2 modify-vpc-attribute --vpc-id ${vpcId} --enable-dns-hostnames

# internet gateway and route table #
####################################
igwId=$(aws ec2 create-internet-gateway --output text --query 'InternetGateway.InternetGatewayId')
idArray+=(${igwId})
echo "igwId [${igwId}]"

aws ec2 attach-internet-gateway --internet-gateway-id ${igwId} --vpc-id ${vpcId}

rtbId=$(aws ec2 describe-route-tables --filters Name=vpc-id,Values=${vpcId} --output text --query 'RouteTables[*].RouteTableId')
idArray+=(${rtbId})
echo "rtbId [${rtbId}]"

# az1 Subnet and route table #
##############################

az1SubnetId=$(aws ec2 create-subnet --vpc-id ${vpcId} --availability-zone "${azRoot}a" --cidr-block 172.31.0.0/20 --output text --query 'Subnet.SubnetId')
idArray+=(${az1SubnetId})
echo "az1SubnetId [${az1SubnetId}]"

# associate this subnet with our route table
aws ec2 associate-route-table --subnet-id ${az1SubnetId} --route-table-id ${rtbId}

# az2 Subnet and route table #
##############################

az2SubnetId=$(aws ec2 create-subnet --vpc-id ${vpcId} --availability-zone "${azRoot}b" --cidr-block 172.31.16.0/20 --output text --query 'Subnet.SubnetId')
idArray+=(${az2SubnetId})
echo "az2SubnetId [${az2SubnetId}]"

# associate this subnet with our route table
aws ec2 associate-route-table --subnet-id ${az2SubnetId} --route-table-id ${rtbId}

# Create a route in the IGW #
#############################

# create a route out from our route table to the igw
aws ec2 create-route --route-table-id ${rtbId} --gateway-id ${igwId} --destination-cidr-block 0.0.0.0/0

# Security groups #
###################

ec2SG=$(aws ec2 create-security-group --vpc-id ${vpcId} --group-name ${project}-ec2-sg --description "EC2 security group" --output text --query 'GroupId')
idArray+=(${ec2SG})
echo "ec2SG [${ec2SG}]"

lbSG=$(aws ec2 create-security-group --vpc-id ${vpcId} --group-name ${project}-lb-sg --description "Load balancer security group" --output text --query 'GroupId')
idArray+=(${lbSG})
echo "lbSG [${lbSG}]"

# ec2 ingress rules
#
allFromCIDR=$(aws ec2 authorize-security-group-ingress --group-id ${ec2SG} --protocol all --cidr "82.10.149.166/32")
port8080FromSG=$(aws ec2 authorize-security-group-ingress --group-id ${ec2SG} --protocol tcp --port 8080 --source-group ${lbSG})

# lb ingress rules
#
port80FromCIDR=$(aws ec2 authorize-security-group-ingress --group-id ${lbSG} --protocol tcp --port 80 --cidr "82.10.149.166/32")

# load balancer
#
lbArn=$(aws elbv2 create-load-balancer --name ${project}-80-lb --subnets ${az1SubnetId} ${az2SubnetId} --security-groups ${lbSG} --output text --query 'LoadBalancers[0].LoadBalancerArn')
echo "lbArn [${lbArn}]"
#idArray+=(${lbArn})

# target group for lb - accept defaults
#
targetGroupArn=$(aws elbv2 create-target-group --name ${project}-8080-tg --protocol HTTP --port 8080 --health-check-path /profile --vpc-id ${vpcId} --output text --query 'TargetGroups[0].TargetGroupArn')
echo "targetGroupArn [${targetGroupArn}]"
#idArray+=(${targetGroupArn})

# create EC2 instance in each  - KLUGE - we need to have previously made the image from an EC2 instance with our app installed !! :(
#
az1ec2=$(aws ec2 run-instances --image-id ${amiId} --key-name ${project} --security-group-ids ${ec2SG} --subnet-id ${az1SubnetId} --associate-public-ip-address --user-data file://user-data.bash --instance-type t2.micro --placement AvailabilityZone="${azRoot}a",Tenancy=default --output text --query "Instances[0].InstanceId")
echo "az1ec2 [${az1ec2}]"
idArray+=(${az1ec2})

./waitForInstance.bash ${az1ec2} pending

az2ec2=$(aws ec2 run-instances --image-id ${amiId} --key-name ${project} --security-group-ids ${ec2SG} --subnet-id ${az2SubnetId} --associate-public-ip-address --user-data file://user-data.bash --instance-type t2.micro --placement AvailabilityZone="${azRoot}b",Tenancy=default --output text --query "Instances[0].InstanceId")
echo "az2ec2 [${az2ec2}]"
idArray+=(${az2ec2})

./waitForInstance.bash ${az2ec2} pending

# register targets in the lb for the EC2 instances in each AZ
#
aws elbv2 register-targets --target-group-arn ${targetGroupArn} --targets Id=${az1ec2} Id=${az2ec2}

# create a listener
#
listenerArn=$(aws elbv2 create-listener --load-balancer-arn ${lbArn} --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=${targetGroupArn} --output text --query "Listeners[0].ListenerArn")
echo "listenerArn [${listenerArn}]"
#idArray+=(${listenerArn})

# tags ids with common Name tag
#
for id in "${idArray[@]}"
do
    echo "Tagging [${id}] with Name=${project}"
    aws ec2 create-tags --resources ${id} --tags Key=Name,Value=${project}
done

echo "Complete"

echo "Generating removal script..."
removalScript="remove_${project}.bash"
echo "#!/bin/bash" > ${removalScript}
echo "" >> ${removalScript}
DIR=`pwd`
echo "DIR=${DIR}" >> ${removalScript}
echo "echo 'Removing resources for ${project}...'" >> ${removalScript}

echo "aws ec2 terminate-instances --instance-ids ${az1ec2} ${az2ec2}" >> ${removalScript}

echo "${DIR}/waitForInstance.bash ${az1ec2} shutting-down" >> ${removalScript}
echo "${DIR}/waitForInstance.bash ${az2ec2} shutting-down" >> ${removalScript}

echo "aws elbv2 delete-listener --listener-arn ${listenerArn}" >> ${removalScript}
echo "aws elbv2 delete-target-group --target-group-arn ${targetGroupArn}" >> ${removalScript}
echo "aws elbv2 delete-load-balancer --load-balancer-arn ${lbArn}" >> ${removalScript}

echo "aws ec2 delete-security-group --group-id ${ec2SG}" >>  ${removalScript}
echo "aws ec2 delete-security-group --group-id ${lbSG}" >>  ${removalScript}

echo "aws ec2 delete-subnet --subnet-id ${az1SubnetId}" >>  ${removalScript}
echo "aws ec2 delete-subnet --subnet-id ${az2SubnetId}" >>  ${removalScript}

echo "aws ec2 detach-internet-gateway --internet-gateway-id ${igwId} --vpc-id ${vpcId}" >> ${removalScript}
echo "aws ec2 delete-internet-gateway --internet-gateway-id ${igwId}" >> ${removalScript}
echo "aws ec2 delete-vpc --vpc-id ${vpcId}" >>  ${removalScript}
echo "aws ec2 delete-route-table --route-table-id ${rtbId}" >> ${removalScript}

echo "aws ec2 delete-key-pair --key-name ${project}" >>  ${removalScript}
echo "echo 'Removed resources for ${project}...'" >> ${removalScript}

echo "removalScript [${removalScript}]"

chmod -v 755 ${removalScript}

#bash -x ${removalScript}

popd



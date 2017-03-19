#!/bin/bash


aws ec2 run-instances --image-id ami-0eacb96a --key-name test-ec2-london-2 --security-group-ids sg-962d84ff sg-69fb5000 --user-data file://user-data.bash --instance-type t2.micro --placement AvailabilityZone=eu-west-2a,Tenancy=default
aws ec2 run-instances --image-id ami-0eacb96a --key-name test-ec2-london-2 --security-group-ids sg-962d84ff sg-69fb5000 --user-data file://user-data.bash --instance-type t2.micro --placement AvailabilityZone=eu-west-2b,Tenancy=default

#aws ec2 run-instances --cli-input-json file://launch-candidate.json --security-group-ids sg-962d84ff sg-69fb5000
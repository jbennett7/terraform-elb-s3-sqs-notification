#!/bin/bash
echo "Please read this script carefully before executing."
exit 1
NAME=Splunk
VPC_STACK_NAME=${NAME}-VpcStack
SECURITY_GROUP_NAME=${NAME}-SecurityGroup
KEY_PAIR_NAME=
AWS='aws'

VPC_ID=$(${AWS} ec2 describe-vpcs \
    --query 'Vpcs[0].VpcId' \
    --output text)
SUBNET_IDS=$(${AWS} ec2 describe-subnets \
    --filters Name=vpc-id,Values=${VPC_ID} \
    --query 'Subnets[].SubnetId' \
    --output text)  
SECURITY_GROUP=$(${AWS} ec2 describe-security-groups \
    --filters Name=vpc-id,Values=${VPC_ID} \
    --query 'SecurityGroups[?GroupName==`'${SECURITY_GROUP_NAME}'`].GroupId' \
    --output text)

############### ELBv2 ############################
#echo "Building Loadbalancer"
#ELBV2_OUTPUT=$(${AWS} elbv2 \
#    --name splunk-elb \
#    --subnets ${SUBNET_IDS} \
#    --security_groups ${SECURITY_GROUPS} \
#    --query 'LoadBalancers[].[LoadBalancerArn, DNSName]' \
#    --output text)
#ELBV2_ARN=$(echo ${ELBV2_OUTPUT}|awk '{print $1}')
#ELBV2_DNSNAME=$(echo ${ELBV2_OUTPUT}|awk '{print $2}')
#
#echo "Request Certificate"
#CERT_ARN=$(${AWS} acm request-certificate \
#    --domain-name ${ELBV2_DNSNAME} \
#    --validation-method DNS \
#    --query CertificateArn \
#    --output text)
#echo "Setup Validation"
############### ELBv2 ############################

echo "Building Application build instance."
INSTANCE_ID=$(${AWS} ec2 run-instances \
    --image-id ami-04763b3055de4860b \
    --count 1 \
    --instance-type t2.medium \
    --key-name ${KEY_PAIR_NAME} \
    --security-group-ids ${SECURITY_GROUP} \
    --subnet-id $(echo ${SUBNET_IDS}|awk '{print $1}') \
    --associate-public-ip-address \
    --iam-instance-profile Name=splunk \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME}-Instance}]" \
    --block-device-mappings file://mappings.json \
    --user-data file://splunk-userdata.txt \
    --query 'Instances[].InstanceId' \
    --output text|sed 's/\t/ /g')
echo "Waiting for splunk instance ${INSTANCE_ID} to become available." 
${AWS} ec2 wait instance-running \
    --instance-ids $(echo ${INSTANCE_ID}|awk '{print $1}')
sleep 2
${AWS} ec2 describe-instances \
    --instance-ids ${INSTANCE_ID} \
    --query 'Reservations[].Instances[].PublicIpAddress' \
    --output text
sleep 2
TARGETS=$(${AWS} elbv2 describe-target-groups \
    --query 'TargetGroups[].TargetGroupArn' \
    --output text)
for target in ${TARGETS};do
    ${AWS} elbv2 register-targets \
        --target-group-arn ${target} \
        --targets Id=${INSTANCE_ID}
done

#echo "Building Application build instance."
#INSTANCE_ID=$(${AWS} ec2 run-instances \
#    --image-id ami-04763b3055de4860b \
#    --count 1 \
#    --instance-type t2.medium \
#    --key-name ${KEY_PAIR_NAME} \
#    --security-group-ids ${SECURITY_GROUP} \
#    --subnet-id $(echo ${SUBNET_IDS}|awk '{print $1}') \
#    --associate-public-ip-address \
#    --iam-instance-profile Name=splunk \
#    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME}-Instance}]" \
#    --block-device-mappings file://mappings.json \
#    --user-data file://jenkins-userdata.txt \
#    --query 'Instances[].InstanceId' \
#    --output text|sed 's/\t/ /g')
#echo "Waiting for jenkins instance ${INSTANCE_ID} to become available."
#${AWS} ec2 wait instance-running \
#    --instance-ids $(echo ${INSTANCE_ID}|awk '{print $1}')
#sleep 2
#${AWS} ec2 describe-instances \
#    --instance-ids ${INSTANCE_ID} \
#    --query 'Reservations[].Instances[].PublicIpAddress' \
#    --output text

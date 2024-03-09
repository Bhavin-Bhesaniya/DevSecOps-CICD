#!/bin/bash

# Set your AWS region and EKS cluster name
AWS_REGION="ap-south-1"
CLUSTER_NAME="Three-Tier-Cluster"

# Set the desired number of worker nodes
NODES_COUNT=2

# Set subnet IDs
SUBNET_ID_1="subnet-0f18c825effb6dc9a"
SUBNET_ID_2="subnet-07ff243b0a794b6bd"

# Roles ARN
CLUSTER_ROLE_ARN="arn:aws:iam::490108295743:role/My-Cluster-Role"
NODE_ROLE_ARN="arn:aws:iam::348949640551:role/aws-service-role/eks-nodegroup.amazonaws.com/AWSServiceRoleForAmazonEKSNodegroup"

# Set Security Group ID
SECURITY_ID="sg-02233bc70486ad341"

# Set the instance type for worker nodes
INSTANCE_TYPE="t2.medium"

# Create the EKS cluster
aws eks create-cluster \
  --region $AWS_REGION \
  --name $CLUSTER_NAME \
  --role-arn $CLUSTER_ROLE_ARN \
  --resources-vpc-config subnetIds=$SUBNET_ID_1,$SUBNET_ID_2,securityGroupIds=$SECURITY_ID \
  --kubernetes-version 1.21

# Wait for the cluster to be in the "ACTIVE" status
echo "Waiting for cluster creation..."
aws eks wait cluster-active --region $AWS_REGION --name $CLUSTER_NAME

# Create a kubeconfig file for the EKS cluster
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Create worker nodes using managed node group
aws eks create-nodegroup \
  --region $AWS_REGION \
  --cluster-name $CLUSTER_NAME \
  --nodegroup-name eks-workers \
  --subnets $SUBNET_ID_1 $SUBNET_ID_2 \
  --instance-types $INSTANCE_TYPE \
  --disk-size 20 \
  --node-role $NODE_ROLE_ARN \
  --scaling-config minSize=1,maxSize=$NODES_COUNT,desiredSize=$NODES_COUNT

echo "EKS cluster creation completed."
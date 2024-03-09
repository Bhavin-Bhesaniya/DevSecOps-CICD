#!/bin/bash
AWS_REGION="ap-south-1"
CLUSTER_NAME="Three-Tier-Cluster"
NODEGROUP_NAME="ng-7f706939"
CLUSTER_NAME="Three-Tier-Cluster"


# Delete the node group
aws eks --region $AWS_REGION delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP_NAME

# Wait for node group deletion to complete
echo "Waiting for node group deletion..."
aws eks --region $AWS_REGION wait nodegroup-deleted --cluster-name $CLUSTER_NAME --nodegroup-name $NODEGROUP_NAME

# Delete the EKS cluster
aws eks --region $AWS_REGION delete-cluster --name $CLUSTER_NAME

# Wait for cluster deletion to complete
echo "Waiting for cluster deletion..."
aws eks --region $AWS_REGION wait cluster-deleted --name $CLUSTER_NAME

echo "EKS cluster and associated resources deletion completed."
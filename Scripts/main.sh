#!/bin/bash
echo -e "Welcom to DevSecOpc CICD Project Please Provice Some variable value to Process Furthermore\n"

# read -p "Enter EKS Cluster Name: " 
# read -p "Enter Your AWS Account ID: " 
# read -p "Enter Your AWS REGION: " 
# read -p "Enter Instance Tyes - Ex(t2.medium): " 
# read -p "Enter EKS Node Types - Ex(t2.medium) : "
# read -p "Enter Total No. of Nodes - " 
CLUSTER_NAME="Three-Tier-Cluster"
AWS_ACCOUNT_ID="348949640551"
AWS_REGION="ap-south-1"
INSTANCE_TYPE="t2.medium"
NODE_TYPE="t2.medium"
NODES_COUNT="2"
CLUSTER_ROLE_ARN="arn:aws:eks:ap-south-1:348949640551:cluster/Three-Tier-Cluster"
DEFAULT_OUTPUT_FORMAT="json"

read -p "Please provide the AWS Access Key ID: " ACCESS_KEY_ID
read -p "Please provide the AWS Secret Access Key: " SECRET_KEY_ID
aws configure set aws_access_key_id $ACCESS_KEY_ID
aws configure set aws_secret_access_key $SECRET_KEY_ID
aws configure set default.region $AWS_REGION
aws configure set default.output $DEFAULT_OUTPUT_FORMAT


LOAD_BALANCER_IAM_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
LOAD_BALANCER_CONTROLLER_NAME="aws-load-balancer-controller"
LOAD_BALANCER_CONTROLLER_ROLE_NAME="AmazonEKSLoadBalancerControllerRole"
LOAD_BALANCER_NAMESPACE="kube-system"

FRONTEND_REPO="frontend-repo"
BACKEND_REPO="backend-repo"


# read -p "Enter Subnet ID - 1 Where EKS Cluster Created: " 
# read -p "Enter Subnet ID - 2 Where EKS Cluster Created: " 
# read -p "Enter Security Group ID - Where EKS Cluster Created: " 
# read -p "Enter Node_Group_Name After EKS Cluster Created: " 
# read -p "Enter Node_Role_ARN After EKS Cluster Created: " 
SUBNET_ID_1="subnet-029a870bb477018e5"
SUBNET_ID_2="subnet-0fe9d184bf991a5fd"
SECURITY_ID="sg-03a2c4de3fbd66e4a"
NODE_GROUP_NAME="ng-e13773dd"
NODE_ROLE_ARN="arn:aws:iam::348949640551:role/eksctl-Three-Tier-Cluster-nodegrou-NodeInstanceRole-t0Kky4JokGrH"


echo -e "${AWS_REGION},${CLUSTER_NAME},${AWS_ACCOUNT_ID},${SUBNET_ID_1},${SUBNET_ID_2},${SECURITY_ID},${NODES_COUNT},${INSTANCE_TYPE},${CLUSTER_ROLE_ARN},${NODE_ROLE_ARN} \n"


###############################################################################################################################################################
# Creating the EKS cluster
cluster_exists=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.name" --output text 2>/dev/null)  # Check if EKS cluster already exists
###############################################################################################################################################################
if [ "$cluster_exists" == "$CLUSTER_NAME" ]; then
    echo "EKS cluster '$CLUSTER_NAME' already exists. Skipping cluster creation."
else
  echo -e "Creating AWS EKS cluster................................\n" 
  eksctl create cluster --name $CLUSTER_NAME --region $AWS_REGION --node-type $NODE_TYPE --nodes-min $NODES_COUNT --nodes-max $NODES_COUNT
  if [ $? -ne 0 ]; then
    echo "Failed to create EKS cluster. Exiting."
    exit 1
  fi
fi

echo -e "Waiting for upto 15 minutes to cluster creation... tobe in the 'ACTIVE' status\n"  # kubectl get nodes # WAIT 15 UPTO MINUTES
aws eks wait cluster-active --region $AWS_REGION --name $CLUSTER_NAME
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME                         # Create a kubeconfig file for the EKS cluster
kubectl get nodes 

sleep 10s
# Create worker nodes using managed node group
nodegroup_exists=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP_NAME --region $AWS_REGION --query "nodegroup.nodegroupName" --output text 2>/dev/null)
if [ "$nodegroup_exists" == $NODE_GROUP_NAME ]; then
  echo "Node group 'eks-workers' already exists. Skipping node group creation."
else
  echo -e "Creating node group................................\n"
  aws eks create-nodegroup \
    --region $AWS_REGION \
    --cluster-name $CLUSTER_NAME \
    --nodegroup-name $NODE_GROUP_NAME \
    --subnets $SUBNET_ID_1, $SUBNET_ID_2 \
    --instance-types $INSTANCE_TYPE \
    --disk-size 20 \
    --node-role $NODE_ROLE_ARN \
    --scaling-config minSize=1, maxSize=$NODES_COUNT,desiredSize=$NODES_COUNT
  if [ $? -ne 0 ]; then
    echo "Failed to create node group. Exiting."
    exit 1
  fi
fi
echo -e "EKS cluster creation completed. \n\n"


###############################################################################################################################################################
### Load Balancer On EKS #####
###############################################################################################################################################################
echo "Load Balancer On EKS and Policy Setup ................................"
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json  # Download IAM policy document
aws iam create-policy --policy-name $LOAD_BALANCER_IAM_POLICY_NAME --policy-document file://iam_policy.json                 # Create IAM policy
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster=$CLUSTER_NAME --approve                             # Associate IAM OIDC provider with EKS cluster


echo "Adding Helm repository................................"
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
sleep 5s

LOAD_BALANCER_EXISTS=$(aws elbv2 describe-load-balancers --names $LOAD_BALANCER_NAME --region $AWS_REGION --query 'LoadBalancers[*].LoadBalancerName' --output text)
if [ "$LOAD_BALANCER_EXISTS" == "$LOAD_BALANCER_NAME" ]; then
  echo "Load Balancer '$LOAD_BALANCER_NAME' already exists. Skipping creation."
else
  echo "Creating Load Balancer using helm................................"
  eksctl create iamserviceaccount \
    --cluster=$CLUSTER_NAME \
    --namespace=$LOAD_BALANCER_NAMESPACE \
    --name=$LOAD_BALANCER_CONTROLLER_NAME \
    --role-name $LOAD_BALANCER_CONTROLLER_ROLE_NAME \
    --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
    --approve \
    --region=$AWS_REGION
  
  helm install $LOAD_BALANCER_CONTROLLER_NAME eks/$LOAD_BALANCER_CONTROLLER_NAME \
    -n $LOAD_BALANCER_NAMESPACE \
    --set clusterName=$CLUSTER_NAME \
    --set serviceAccount.name=$LOAD_BALANCER_CONTROLLER_NAME  # --set serviceAccount.create=false \  
  sleep 10s
fi
kubectl get deployment -n $LOAD_BALANCER_NAMESPACE $LOAD_BALANCER_CONTROLLER_NAME   # After 2 mintues
sleep 5s


###############################################################################################################################################################
# Create 2 ECR Repository Private (Frontend-Repo) and (Backend-Repo) then login
###############################################################################################################################################################
aws ecr create-repository --repository-name $FRONTEND_REPO --region $AWS_REGION
aws ecr create-repository --repository-name $BACKEND_REPO --region $AWS_REGION

# Check if the login was successful
if [ $? -eq 0 ]; then
    aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    echo "Successfully logged in to AWS ECR."
else
    echo "Error: Failed to log in to AWS ECR. Please check your AWS credentials and try again."
    exit 1
fi
echo "Successfully logged in to AWS ECR."
sleep 10s


###############################################################################################################################################################
#### Argocd.sh #####
###############################################################################################################################################################
ARGO_CD_NAMESPACE=argo-cd
ARGO_RELEASE_NAME=argo

echo "Checking if EKS cluster is ready..."
cluster_status=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.status" --output text)

if [ "$cluster_status" == "ACTIVE" ]; then
  echo " !!! Eks is Ready !!! and Creat Argo-cd namespace"
  kubectl create namespace ${ARGO_CD_NAMESPACE} || true 

  echo " Deploy argo-cd on eks "
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  helm install ${ARGO_RELEASE_NAME} argo/argo-cd -n ${ARGO_CD_NAMESPACE} || true 
  kubectl patch svc ${ARGO_RELEASE_NAME}-argocd-server -n ${ARGO_CD_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'
  kubectl get service ${ARGO_RELEASE_NAME}-argocd-server -n ${ARGO_CD_NAMESPACE} | awk '{print $4}'

  echo "--------------------ArgoCD UI Admin and Password--------------------"
  kubectl -n ${ARGO_CD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argo-pass.txt
  cat argo-pass.txt
else
  echo " Eks is not working "
fi

echo -e " To access the argoCD, copy the LoadBalancer DNS and hit on your favorite browser.\n"
sleep 10s

###############################################################################################################################################################
# Create Kubernetes namespace
###############################################################################################################################################################
# As you know, Our two ECR repositories are private. So, when we try to push images to the ECR Repos it will give us the error Imagepullerror.
# To get rid of this error, we will create a secret for our ECR Repo in the same application namespcae, 
# Three-tier namespace by the below command and then, we will add this secret to the deployment file.
# Note: The Secrets are coming from the .docker/config.json file which is created while login the ECR in the earlier steps

TT_NAMESPACE=three-tier
echo "Creating secrets for ECR Repo in the three-tier namespace........... : ${TT_NAMESPACE}"
kubectl create namespace $TT_NAMESPACE || {
  echo "Error: Failed to create namespace ${TT_NAMESPACE}. Please check your Kubernetes configuration."
  exit 1
}

# Create Kubernetes secret for ECR registry
echo "Namespace ${NAMESPACE} created successfully. Now Creating Kubernetes secret for ECR registry... "

kubectl create secret generic ecr-registry-secret \
  --from-file=.dockerconfigjson=${HOME}/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson --namespace $TT_NAMESPACE  || {
    echo "Error: Failed to create Kubernetes secret. Please check your Docker configuration and try again."
    exit 1
}
echo "Kubernetes secret created successfully."
kubectl get secrets -n $TT_NAMESPACE
echo -e "Add Secret into deployment file in the three-tier namespace\n"


###############################################################################################################################################################
### Prometheus & Grafana on EKS #####
###############################################################################################################################################################
PG_NAMESPACE=default
PG_RELEASE_NAME=prometheus-community

check_eks_cluster_readiness() {
    # Example: Check if a specific service is running in the cluster
    kubectl get svc -n kube-system | grep -q 'kube-dns'
}

# Check if the EKS cluster is ready
if check_eks_cluster_readiness && [ $? -eq 0 ]; then
  echo " !!! Eks is Ready !!! "

  echo " Create Monitoring namespace "
  kubectl create namespace ${PG_NAMESPACE} || true 

  echo " Deploy prometheus on eks "
  helm repo add ${PG_RELEASE_NAME} https://prometheus-community.github.io/helm-charts
  helm repo update
  helm install prometheus ${PG_RELEASE_NAME}/kube-prometheus-stack

  echo " Wait Pods to Start "
  sleep 2m

  echo " Change prometheus service to LoadBalancer "
  kubectl patch svc prometheus-kube-prometheus-prometheus -n ${PG_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'
  kubectl patch svc prometheus-grafana -n ${PG_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'
  echo "--------------------Creating External-IP--------------------"
  sleep 10s

  echo "--------------------Prometheus & Grafana Ex-URL--------------------"
  kubectl get service prometheus-kube-prometheus-prometheus -n ${PG_NAMESPACE} | awk '{print $4}'
  kubectl get service prometheus-grafana -n ${PG_NAMESPACE} | awk '{print $4}'

else
  echo " Eks is not working "
fi
echo -e " To access the Prometheus & Grafana, copy the LoadBalancer DNS and hit on your favorite browser.\n"
echo "Completed successfully Script Execution......................................................"
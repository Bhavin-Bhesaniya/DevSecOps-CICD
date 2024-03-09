#!/bin/bash
echo -e "Welcom to DevSecOpc CICD Project Please Provice Some variable value to Process Furthermore\n"

###############################################################################################################################################################
# Variables
###############################################################################################################################################################
CLUSTER_NAME="Three-Tier-Cluster"
AWS_REGION="ap-south-1"
AWS_ACCOUNT_ID=""

SUBNET_ID_1="YourSubnetID1"
SUBNET_ID_2="YourSubnetID2"
SECURITY_ID="YourSecurityGroupID"
NODES_COUNT="YourNodesCount"

INSTANCE_TYPE="t2.medium"
NODE_GROUP_NAME="eks-workers"
NODE_TYPE="t2.medium"
NODES_COUNT="2"
CLUSTER_ROLE_ARN="YourClusterRoleARN"
NODE_ROLE_ARN="YourNodeRoleARN"

LOAD_BALANCER_IAM_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
LOAD_BALANCER_CONTROLLER_NAME="aws-load-balancer-controller"
LOAD_BALANCER_CONTROLLER_ROLE_NAME="AmazonEKSLoadBalancerControllerRole"
LOAD_BALANCER_NAMESPACE="kube-system"
FRONTEND_REPO="Frontend-Repo"
PRIVATE_REPO="Private-Repo"

echo -e "${AWS_REGION},${CLUSTER_NAME},${AWS_ACCOUNT_ID},${SUBNET_ID_1},${SUBNET_ID_2},${SECURITY_ID},${NODES_COUNT},${INSTANCE_TYPE},${CLUSTER_ROLE_ARN},${NODE_ROLE_ARN} \n"


###############################################################################################################################################################
# Creating the EKS cluster
###############################################################################################################################################################
# Check if EKS cluster already exists
cluster_exists=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.name" --output text 2>/dev/null)

if [ "$cluster_exists" == "$CLUSTER_NAME" ]; then
    echo "EKS cluster '$CLUSTER_NAME' already exists. Skipping cluster creation."
else
  echo -e "Creating AWS EKS cluster................................\n" 
  aws eks create-cluster \
    --name $CLUSTER_NAME \
    --region $AWS_REGION \
    --node-type $NODE_TYPE \
    --role-arn $CLUSTER_ROLE_ARN \
    --resources-vpc-config subnetIds=$SUBNET_ID_1,$SUBNET_ID_2, securityGroupIds=$SECURITY_ID \
    --kubernetes-version 1.21
  if [ $? -ne 0 ]; then
    echo "Failed to create EKS cluster. Exiting."
    exit 1
  fi

echo -e "Waiting for upto 15 minutes to cluster creation... tobe in the 'ACTIVE' status\n"  # kubectl get nodes # WAIT 15 UPTO MINUTES
aws eks wait cluster-active --region $AWS_REGION --name $CLUSTER_NAME
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME       # Create a kubeconfig file for the EKS cluster


# Create worker nodes using managed node group
nodegroup_exists=$(aws eks describe-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $NODE_GROUP_NAME --region $AWS_REGION --query "nodegroup.nodegroupName" --output text 2>/dev/null)
if [ "$nodegroup_exists" == "eks-workers" ]; then
  echo "Node group 'eks-workers' already exists. Skipping node group creation."
else
  echo -e "Creating node group................................\n"
  aws eks create-nodegroup \
    --region $AWS_REGION \
    --cluster-name $CLUSTER_NAME \
    --nodegroup-name $NODE_GROUP_NAME \
    --subnets $SUBNET_ID_1 $SUBNET_ID_2 \
    --instance-types $INSTANCE_TYPE \
    --disk-size 20 \
    --node-role $NODE_ROLE_ARN \
    --scaling-config minSize=1,maxSize=$NODES_COUNT,desiredSize=$NODES_COUNT
  if [ $? -ne 0 ]; then
    echo "Failed to create node group. Exiting."
    exit 1
  fi
echo -e "EKS cluster creation completed. \n\n"


###############################################################################################################################################################
### Load Balancer On EKS #####
###############################################################################################################################################################
echo "Load Balancer On EKS................................"
echo "Load Balancer Policy Setup ................................"
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json  # Download IAM policy document
aws iam create-policy --policy-name $LOAD_BALANCER_IAM_POLICY_NAME --policy-document file://iam_policy.json                 # Create IAM policy
eksctl utils associate-iam-oidc-provider --region=$AWS_REGION --cluster=$CLUSTER_NAME --approve                             # Associate IAM OIDC provider with EKS cluster

# Create IAM service account for aws-load-balancer-controller
echo "Creating IAM service account for aws-load-balancer-Controller................................"
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=$LOAD_BALANCER_NAMESPACE \
  --name=$LOAD_BALANCER_CONTROLLER_NAME \
  --role-name $LOAD_BALANCER_CONTROLLER_ROLE_NAME \
  --attach-policy-arn=arn:aws:iam::$AWS_ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy \
  --approve \
  --region=$AWS_REGION

# Install Helm (if not installed)
echo "Checking helm installation................................"
if ! command -v helm &> /dev/null; then
    sudo snap install helm --classic
fi

###############################################################################################################################################################
# Add Helm repository
###############################################################################################################################################################
echo "Adding Helm repository................................"
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

# Install AWS Load Balancer Controller using Helm
echo "Installing AWS Load Balancer Controller using helm"
helm install $LOAD_BALANCER_CONTROLLER_NAME eks/$LOAD_BALANCER_CONTROLLER_NAME   \
  -n $LOAD_BALANCER_NAMESPACE \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=$LOAD_BALANCER_CONTROLLER_NAME


# After 2 mintues
echo "Installing AWS Load Balancer Controller using Helm... Wait for 2 minutes"
kubectl get deployment -n $LOAD_BALANCER_NAMESPACE $LOAD_BALANCER_CONTROLLER_NAME




###############################################################################################################################################################
# Create 2 ECR Repository Private (Frontend-Repo) and (Backend-Repo) then login
###############################################################################################################################################################
aws ecr create-repository --repository-name $FRONTEND_REPO --region $AWS_REGION
aws ecr create-repository --repository-name $PRIVATE_REPO --region $AWS_REGION

echo "Logging in to AWS ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"


# if ! aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"; then
    # echo "Error: Failed to log in to AWS ECR. Please check your AWS credentials and try again."
    # exit 1
# fi
# Check if the login was successful
if [ $? -eq 0 ]; then
    echo "Successfully logged in to AWS ECR."
else
    echo "Error: Failed to log in to AWS ECR. Please check your AWS credentials and try again."
    exit 1
fi
echo "Successfully logged in to AWS ECR."



###############################################################################################################################################################
#### Argocd.sh #####
###############################################################################################################################################################
ARGO_CD_NAMESPACE=argo-cd
ARGO_RELEASE_NAME=argo

# Here first check if eks cluster complete or not instead of this file so write condition for it if yes 
echo "Checking if EKS cluster is ready..."
cluster_status=$(aws eks describe-cluster --name $CLUSTER_NAME --region $AWS_REGION --query "cluster.status" --output text)

# if  && [ $? -eq 0 ]; then
if ["$cluster_status" == "ACTIVE" ]; then
   echo " !!! Eks is Ready !!! "
   echo "Create Argo-cd namespace "
   kubectl create namespace ${ARGO_CD_NAMESPACE} || true 

   echo " Deploy argo-cd on eks "
   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update
   helm install ${ARGO_RELEASE_NAME} argo/argo-cd -n ${ARGO_CD_NAMESPACE} || true 

   echo " Wait Pods to Start "
   sleep 2m

   echo " change argocd service to LOAD Balancer "
   kubectl patch svc ${ARGO_RELEASE_NAME}-argocd-server -n ${ARGO_CD_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'

   echo "--------------------Creating External-IP--------------------"
   sleep 10s

   echo "--------------------Argocd Ex-URL--------------------"
   kubectl get service ${ARGO_RELEASE_NAME}-argocd-server -n ${ARGO_CD_NAMESPACE} | awk '{print $4}'

   echo "--------------------ArgoCD UI Password--------------------"
   echo "Username: admin"
   echo "Password of Argo-CD"
   kubectl -n ${ARGO_CD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d > argo-pass.txt
   cat argo-pass.txt

else
   echo " Eks is not working "
fi
echo -e " To access the argoCD, copy the LoadBalancer DNS and hit on your favorite browser.\n"


###############################################################################################################################################################
# Create Kubernetes namespace
###############################################################################################################################################################
<< 'END'
As you know, Our two ECR repositories are private. So, when we try to push images to the ECR Repos it will give us the error Imagepullerror.
To get rid of this error, we will create a secret for our ECR Repo in the same application namespcae, 
Three-tier namespace by the below command and then, we will add this secret to the deployment file.
Note: The Secrets are coming from the .docker/config.json file which is created while login the ECR in the earlier steps
END

echo "Creating secrets for ECR Repo in the three-tier namespace..........."
TT_NAMESPACE=three-tier
echo "Creating Kubernetes namespace: ${TT_NAMESPACE}"
kubectl create namespace $TT_NAMESPACE || {
    echo "Error: Failed to create namespace ${TT_NAMESPACE}. Please check your Kubernetes configuration."
    exit 1
}
echo "Namespace ${NAMESPACE} created successfully."

# Create Kubernetes secret for ECR registry
echo "Creating Kubernetes secret for ECR registry..."
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
# Starting Nginx Configuration for reverse proxy, certbot
###############################################################################################################################################################
echo "Starting Nginx Configuration"
sudo apt upgrade -y
sudo apt install nginx -y
sudo systemctl enable nginx
sudo systemctl start nginx
sudo apt install certbot python3-certbot-nginx -y     # Install Certbot
echo "Installing successfully Nginx and Certbot"

# Create or edit the Nginx configuration file for Jenkins
sudo nano /etc/nginx/sites-available/jen-clovin.duckdns.org

# Configuration content
cat << EOF > /etc/nginx/sites-available/jen-clovin.duckdns.org
upstream jenkins {
    server 127.0.0.1:8080;
}

server {
    listen      80;
    server_name jen-clovin.duckdns.org;

    access_log /var/log/nginx/jenkins.access.log;
    error_log   /var/log/nginx/jenkins.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://jenkins;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto https;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/jen-clovin.duckdns.org /etc/nginx/sites-enabled/    # Enable the site by creating a symbolic link
sudo nginx -t                                                                             # Test for syntax errors
sudo systemctl restart nginx                                                              # Restart Nginx to apply the changes

echo "Openssl configuration for jenkins................................................................"
sudo certbot --nginx -d jen-clovin.duckdns.org --agree-tos --email bkbhesaniya11@gmail.com
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
echo "Certbot configuration Completed for jenkins......................................................"


# Sonarqube
sudo nano /etc/nginx/sites-avaliable/sonar-clovin.duckdns.org
cat << EOF > /etc/nginx/sites-available/sonar-clovin.duckdns.org
upstream sonarqube {
    server 127.0.0.1:8080;
}

server {
    listen      80;
    server_name sonar-clovin.duckdns.org;

    access_log /var/log/nginx/sonarqube.access.log;
    error_log /var/log/nginx/sonarqube.error.log;

    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://sonarqube;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_redirect off;

        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto https;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/sonar-clovin.duckdns.org /etc/nginx/sites-enabled/  # Enable the site by creating a symbolic link
sudo nginx -t                                                                             # Test for syntax errors
sudo systemctl restart nginx                                                              # Restart Nginx to apply the changes

echo "Openssl configuration for sonarqube ................................................................"
sudo certbot --nginx -d sonar-clovin.duckdns.org --agree-tos --email bkbhesaniya11@gmail.com
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
echo "Certbot configuration Completed for sonarqube ......................................................"



###############################################################################################################################################################
# Jenkins Pipeline Status Checking
###############################################################################################################################################################
JENKINS_JOB_NAME="DevSecOps-CICD"  
JENKINS_URL="http://jen-clovin.duckdns.org" 
check_jenkins_job_status() {
    curl -s "$JENKINS_URL/job/$JENKINS_JOB_NAME/lastBuild/api/json?tree=result" | grep '"result":"SUCCESS"'
}
echo "Waiting for Jenkins pipeline to complete..."
while ! check_jenkins_job_status; do
    echo "Jenkins pipeline is still running. Waiting..."
    sleep 60                                                 # Wait for 60 seconds before checking again
done

# Check if the job was successful
if ! check_jenkins_job_status; then
    echo "Error: Jenkins pipeline failed. Exiting script."
    exit 1
fi
echo "Jenkins pipeline completed successfully."


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
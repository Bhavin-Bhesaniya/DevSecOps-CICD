#!/bin/bash

PG_NAMESPACE=default
PG_RELEASE_NAME=prometheus-community

if ./create-eks.sh && [ $? -eq 0 ]; then
   echo " !!! Eks is Ready !!! "

   echo " Create Monitoring namespace "
   kubectl create namespace ${PG_NAMESPACE} || true 

   echo " Deploy prometheus on eks "
   helm repo add ${PG_RELEASE_NAME} https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install prometheus ${PG_RELEASE_NAME}/kube-prometheus-stack

   echo " Wait Pods to Start "
   sleep 2m

   echo " change prometheus service to NodePort "
   kubectl patch svc prometheus-kube-prometheus-prometheus -n ${PG_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'
   kubectl patch svc prometheus-grafana -n ${PG_NAMESPACE} -p '{"spec": {"type": "LoadBalancer"}}'
   echo "--------------------Creating External-IP--------------------"
   sleep 10s

   echo "--------------------Prometheus & Grafana  Ex-URL--------------------"
   kubectl get service prometheus-kube-prometheus-prometheus -n ${PG_NAMESPACE} | awk '{print $4}'
   kubectl get service prometheus-grafana -n ${PG_NAMESPACE} | awk '{print $4}'
   

else
   echo " Eks is not working "
fi
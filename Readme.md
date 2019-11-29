# ACA k8S Deploy Guide

## EKS Cluster Creation

You need AWS credentials (~/.aws/credentials) which have quite a lot permissions. The easiest way is to give the PowerUser permission.

### Create EKS cluster

Use eksctl for creating and connecting to EKS

```
eksctl create cluster -f cluster.yaml
```

For verify the the cluster is up and running use:

```
kubectl get svc
```

As we are using an S3 bucket for ACS you need to grand the nodegroup "ng-1" access to the created bucket.

### Setup & Connect to EKS Dashboard

The k8s dashboard is useful for debugging the k8s deployment \
https://medium.com/@thanhtungvo/create-eks-on-aws-with-ui-694445faf14f

### Connect to existing EKS cluster

Use AWS CLI for configuring your cluster connection (~/.kube/config). Make sure you have the proper AWS permissions for the "EKS Cluster Creation" step. https://docs.aws.amazon.com/eks/latest/userguide/create-kubeconfig.html

```
aws eks --region $REGION update-kubeconfig --name $CLUSTER_NAME
```

For verify the the cluster is up and running use:

```
kubectl get svc
```

## EKS Cluster deletion

Make sure your used AWS account has the same rights as you used for create the cluster. You need to delete the EFS volume and the EKS related roles (Controlplane and Nodegroup) first!

```
eksctl delete cluster -f cluster.yaml
```

## Setting up ExternalDNS for Services on AWS

For configuring the external DNS https://github.com/kubernetes-incubator/external-dns/blob/master/docs/tutorials/aws.md

## DBP

The current DBP contains AIMS (Keycloak), ACS (ADW, Share, Solr, AOS), openLDAP.

### DBP Deployment

1. Create AWS EFS volume for NFS storage. Make sure that you create the EFS volume inside of the VPC from the cluster. For keeping it easy you could use the ControlPlane SG from the Cluster for the SG. After that you need to open the NFS Inbound from the chosen SG for the EFS Volume. Adjust the Makefile and update the NFS server pointing to the EFS volume.

2. Create namespace:

```
kubectl create namespace $NAMESPACE
```

3. Docker Registry Pull Secrets for quay.io images
   https://github.com/Alfresco/alfresco-dbp-deployment#docker-registry-pull-secrets

```
kubectl create secret docker-registry quay-registry-secret --docker-server=quay.io --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_PASSWORD --namespace $NAMESPACE
```

3. Install tiller for helm deployment: \

https://rancher.com/docs/rancher/v2.x/en/installation/ha/helm-init/

```
kubectl -n kube-system create serviceaccount tiller

kubectl create clusterrolebinding tiller \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:tiller

helm init --service-account tiller
```

4. Deploy the DBP together with openLDAP

For deploy the DBP do:

```
make build
make install
```

### DBP URLs

- http://alfresco-identity-service.<hostedZone>/auth
- http://phpldapadmin.<hostedZone>
- http://alfresco-cs-repository.<hostedZone>
- http://alfresco-cs-repository.<hostedZone>/alfresco
- http://alfresco-cs-repository.<hostedZone>/share/page
- http://alfresco-cs-repository.<hostedZone>/workspace/
- http://alfresco-cs-repository.<hostedZone>/api-explorer
- http://alfresco-cs-repository.<hostedZone>/rm-api-explorer

## OpenLDAP

The admin user and some normal users are already defined in openldap-values.yaml. Use phpldapadmin for govern the OpenLDAP user base. Go to http://phpldapadmin.<hostedZone> . \

For login use:

```
Login DN: cn=admin,dc=example,dc=org
Password: admin
```

## DBP teardown

```
make delete
```

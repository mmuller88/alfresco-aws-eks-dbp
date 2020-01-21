# Sensible information. Provide some before exectuing!
export HOSTED_ZONE := ${HOSTED_ZONE}
export REGION := ${REGION}
export ACC_NUMBER := ${ACC_NUMBER}
export CERT_ID := ${CERT_ID}
export DOCKER_USERNAME := ${DOCKER_USERNAME}
export DOCKER_PASSWORD := ${DOCKER_PASSWORD}
# Not sensible information
export CHART_VERSION := 1.5.0
export NAMESPACE := aca-dbp-ids
export NAMESPACE_FARGATE := dev
export REPO_HOST := alfresco-cs-repository.${HOSTED_ZONE}
export AOS_PORT := 80
export SHARE_PORT := 80
export ACS_BASE_URL := http://${REPO_HOST}
export IDENTITY_SERVICE_URL := http://alfresco-identity-service.${HOSTED_ZONE}
export LDAP := ${NAMESPACE}-openldap.${NAMESPACE}
# export LICENSEAPS := $(APS_LICENSE)
# export SECRET_FILE := 
# export SECRET := $(SECRET_FILE)


build: clean
	kubectl -n kube-system create serviceaccount tiller
	kubectl create clusterrolebinding tiller --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
	helm init --service-account tiller --wait
	helm version
	helm init
	helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
	helm repo add alfresco-stable https://kubernetes-charts.alfresco.com/stable
	helm repo add cetic https://cetic.github.io/helm-charts
	helm repo update
	# kubectl create namespace ${NAMESPACE}
	# kubectl create namespace ${NAMESPACE_FARGATE}
	kubectl create secret docker-registry quay-registry-secret --docker-server=quay.io --docker-username=${DOCKER_USERNAME} --docker-password=${DOCKER_PASSWORD} --namespace ${NAMESPACE}
	kubectl create secret docker-registry quay-registry-secret --docker-server=quay.io --docker-username=${DOCKER_USERNAME} --docker-password=${DOCKER_PASSWORD} --namespace ${NAMESPACE_FARGATE}

install:
	sed -e "s#@@HOSTED_ZONE@@#$$HOSTED_ZONE#g" \
		-e "s#@@NAMESPACE@@#$$NAMESPACE#g" \
		-e "s#@@REGION@@#$$REGION#g" \
		-e "s#@@ACC_NUMBER@@#$$ACC_NUMBER#g" \
		-e "s#@@CERT_ID@@#$$CERT_ID#g" \
		ids-values.yaml > ids-values-edit.yaml
	sed -e "s#@@HOSTED_ZONE@@#$$HOSTED_ZONE#g" phpldapadmin-values.yaml > phpldapadmin-values-edit.yaml
	# kubectl create secret generic licenseaps --from-file=${LICENSEAPS} --namespace=${NAMESPACE} --save-config --dry-run -o yaml | kubectl apply -f -
	helm upgrade ${NAMESPACE}-nfs stable/nfs-server-provisioner --install --namespace ${NAMESPACE} -f nfsServerProvisioner-values.yaml --set storageClass.name=${NAMESPACE}
	helm upgrade ${NAMESPACE}-openldap stable/openldap --install \
		--version=1.1.0 \
		--namespace ${NAMESPACE} \
		-f openldap-values.yaml
	helm upgrade ${NAMESPACE}-phpldapadmin cetic/phpldapadmin --install \
		--version=0.1.2 \
		--namespace ${NAMESPACE_FARGATE} \
		-f phpldapadmin-values-edit.yaml \
		--set env.PHPLDAPADMIN_LDAP_HOSTS=${NAMESPACE}-openldap.${NAMESPACE}
	helm upgrade ${NAMESPACE}-dbp alfresco-stable/alfresco-dbp --version 1.5.0 --install \
		--namespace ${NAMESPACE} -f ids-values-edit.yaml \
		--set alfresco-infrastructure.persistence.storageClass.name="${NAMESPACE}-sc" \
		--set alfresco-content-services.alfresco-search.persistence.existingClaim="alfresco-volume-claim" \
		--set alfresco-content-services.share.namespaceOverride="${NAMESPACE_FARGATE}" \
		--set alfresco-process-services.enabled=false \
		--set alfresco-process-services.license.secretName=licenseaps \
		--set alfresco-process-services.postgresql.persistence.storageClass=${NAMESPACE} \
		--set alfresco-sync-service.enabled=false
	# Wait for Pods and DNS propagation
	chmod +x waitForPods.sh && ./waitForPods.sh ${NAMESPACE}
	chmod +x waitForElbPropagation.sh && ./waitForElbPropagation.sh ${ACS_BASE_URL}
	# Configure AIMS, OpenLDAP and Records Managment
	cd scripts && chmod +x configure-aims-saml.sh && ./configure-aims-saml.sh
	cd scripts && chmod +x configure-aims-ldap.sh && ./configure-aims-ldap.sh
	cd scripts && chmod +x openldap-sync.sh && ./openldap-sync.sh
	cd scripts && chmod +x configure-rm.sh && ./configure-rm.sh

delete:
	# kubectl delete -f ${SECRET_FILE} -n ${NAMESPACE} --ignore-not-found
	# kubectl delete secret licenseaps -n ${NAMESPACE} --ignore-not-found
	helm delete --purge ${NAMESPACE}-nfs ${NAMESPACE}-openldap ${NAMESPACE}-phpldapadmin ${NAMESPACE}-dbp 
	@if [ "$$(helm ls | grep ${NAMESPACE} | wc -l)" = "4" ]; then helm delete --purge ${NAMESPACE}-dbp ${NAMESPACE}-nfs ${NAMESPACE}-openldap ${NAMESPACE}-phpldapadmin; fi
	kubectl delete pvc data-${NAMESPACE}-nfs-nfs-server-provisioner-0 data-${NAMESPACE}-postgresql-aps-0 -n ${NAMESPACE} --ignore-not-found
	@sleep 5
	@if [ "$$(kubectl get pods -n ${NAMESPACE} | grep Termin )" != "" ]; then kubectl delete pod $$(kubectl get pods -n ${NAMESPACE}| grep Termin | awk '{print $$1}') -n ${NAMESPACE} --force --grace-period=0 --ignore-not-found; fi
	@if [ "$$(kubectl get pods -n ${NAMESPACE_FARGATE} | grep Termin )" != "" ]; then kubectl delete pod $$(kubectl get pods -n ${NAMESPACE_FARGATE}| grep Termin | awk '{print $$1}') -n ${NAMESPACE_FARGATE} --force --grace-period=0 --ignore-not-found; fi

clean:

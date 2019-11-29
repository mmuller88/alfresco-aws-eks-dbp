export CHART_VERSION := 1.5.0
export NAMESPACE := jx-dbp-ids
export HOSTED_ZONE := <hostedZone>
export REPO_HOST := alfresco-cs-repository.${HOSTED_ZONE}
export AOS_PORT := 80
export SHARE_PORT := 80
export ACS_BASE_URL := http://${REPO_HOST}
export IDENTITY_SERVICE_URL := http://alfresco-identity-service.${HOSTED_ZONE}
export LDAP := ${NAMESPACE}-openldap.${NAMESPACE}
export NFSSERVER := fs-84a51775.efs.eu-west-2.amazonaws.com

build: clean
	helm version
	helm init
	helm repo add alfresco-incubator https://kubernetes-charts.alfresco.com/incubator
	helm repo add alfresco-stable https://kubernetes-charts.alfresco.com/stable
	helm repo add cetic https://cetic.github.io/helm-charts
	helm repo update

install:
	helm upgrade ${NAMESPACE}-nfs stable/nfs-client-provisioner --install \
		--namespace ${NAMESPACE} \
		--set nfs.server="${NFSSERVER}" \
		--set nfs.path="/" \
		--set storageClass.reclaimPolicy="Delete" \
		--set storageClass.name="${NAMESPACE}-sc"
	helm upgrade ${NAMESPACE}-openldap stable/openldap --install \
		--version=1.1.0 \
		--namespace ${NAMESPACE} \
		-f openldap-values.yaml
	helm upgrade ${NAMESPACE} alfresco-incubator/alfresco-dbp --version ${CHART_VERSION} --install \
		--namespace ${NAMESPACE} -f ids-values.yaml \
		--set alfresco-infrastructure.persistence.storageClass.name="${NAMESPACE}-sc" \
		--set alfresco-content-services.alfresco-search.persistence.existingClaim="alfresco-volume-claim" \
		--set alfresco-process-services.enabled=false \
		--set alfresco-sync-service.enabled=false
	helm upgrade ${NAMESPACE}-phpldapadmin cetic/phpldapadmin --install \
		--version=0.1.2 \
		--namespace ${NAMESPACE} \
		-f phpldapadmin-values.yaml \
		--set env.PHPLDAPADMIN_LDAP_HOSTS=${NAMESPACE}-openldap.${NAMESPACE}
  # Wait for Pods and DNS propagation
	chmod +x waitForPods.sh && ./waitForPods.sh ${NAMESPACE}
	chmod +x waitForElbPropagation.sh && ./waitForElbPropagation.sh ${ACS_BASE_URL}
  # Configure AIMS, OpenLDAP and Records Managment
	cd ../docker/scripts && chmod +x configure-aims-saml.sh && ./configure-aims-saml.sh
	cd ../docker/scripts && chmod +x configure-aims-ldap.sh && ./configure-aims-ldap.sh
	cd ../docker/scripts && chmod +x openldap-sync.sh && ./openldap-sync.sh
	cd ../docker/scripts && chmod +x configure-rm.sh && ./configure-rm.sh

delete:
	helm delete --purge ${NAMESPACE} ${NAMESPACE}-nfs ${NAMESPACE}-openldap ${NAMESPACE}-phpldapadmin
clean:

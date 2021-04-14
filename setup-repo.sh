#!/bin/bash

if [ "$HOSTNAME" = "ocpmgm01.llnl.gov" ]; then
  cd /tmp
  [ -d ocp-configs-checklists ] && rm -rf ocp-configs-checklists

  git clone https://github.com/Prestovich/ocp-configs-checklists.git

  cp -rp /tmp/ocp-configs-checklists/rpms /var/www/html
  cd /var/www/html/rpms
  tar xzf ocp4.6-rhel7-rpms.tar.gz
  tar xzf rhel7-ose-4.6.tar.gz

  createrepo -v /var/www/html/rpms
fi


if [ "$HOSTNAME" = "ocpwrk01.llnl.gov" ] || [ "$HOSTNAME" = "ocpwrk02.llnl.gov" ]; then
  cat > /etc/yum.repos.d/ose.repo <<-EOF
	[rhel-7-server-ose-4.6-rpms]
	name=Red Hat OpenShift Container Platform 4.6 (RPMs)
	baseurl=http://localhost/pub/rpms
	enabled=1
	gpgcheck=0
	EOF
  
  yum repolist
  yum list cri-tools
fi

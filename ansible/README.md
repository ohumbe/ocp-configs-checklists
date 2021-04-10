# Standalone Non-Production Quay for Disconnected OpenShift 4 Installation

This repository will deploy a standalone instance of Quay using local storage on the container host.  It was written with the intention of using it as disconnected registry for installing OpenShift 4.  However, one can leverage just the Quay setup portion in order to work just with Quay itself.

> This repo is most ideal for Home Lab and Proof-of-Concept scenarios. All work for setting up Quay is based on the documentation located [here](https://access.redhat.com/documentation/en-us/red_hat_quay/3.4/html/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index).

## Infrastructure Prerequisites

1. Host running podman
> Tested with:
>  * podman 2.2.1
>  * RHEL 8.3
2. Approximately 20G disk space available
> This should be sufficient space to mirror one release version of OpenShift 4 to Quay.  More space will be required to mirror additional versions and/or mirror operators.

## Quickstart
### Update Ansible inventory
In either `/etc/ansible/hosts` or a local `inventory.yml`, configure your inventory for your container host using a local connection.
```
registry:
  hosts:
    registry.example.com:
  vars:
    ansible_connection: local
```
### Set Global Variables
> Pre-populated entries are set in **disconnected-registry-vars.yml** and are ready to be used.  However, the values should be customized to your particular environment.
1. `skip_pkg_install`: Defaults to *false* assuming a truly disconnected registry host.  Setting to *true* will ensure `required_pkgs` are installed.
2. `base_dir`: A filesystem with at least 20G free for all Quay data to be stored.

3. Downloadable link to `govc` (vSphere CLI, *pre-populated*)
4. OpenShift cluster
   1. base domain *(pre-populated with **example.com**)*
   2. cluster name *(pre-populated with **ocp4**)*
5. HTTP URL of the ***bootstrap.ign*** file *(pre-populated with an example config pointing to helper node)*
6. Furnish any proxy details with the section like below.
   * If `proxy.enabled` is set to `False` anything defined under proxy and the proxy setup is ignored
   * The `cert_content` shown below is only for illustration to show the format
   * When there is no certificate, leave the variable `cert_content` value empty
   ```
   proxy:
      enabled: true
      http_proxy: http://helper.ocp4.example.com:3129
      https_proxy: http://helper.ocp4.example.com:3129
      no_proxy: example.com
      cert_content: |
         -----BEGIN CERTIFICATE-----
            <certficate content>
         -----END CERTIFICATE-----
   ```
7. When doing the restricted network install and following instructions from [restricted.md](restricted.md), furnish details related to the registry with a section like below. If `registry.enabled` is set to `False` anything defined under `registry` and the registry setup is ignored
   ```
   registry:
      enabled: true
      product_repo: openshift-release-dev
      product_release_name: ocp-release
      product_release_version: 4.4.0-x86_64
      username: ansible
      password: ansible
      email: user@awesome.org
      cert_content:
      host: helper.ocp4.example.com
      port: 5000
      repo: ocp4/openshift4
   ```
8. If you wish to install without enabling the Kubernetes vSphere Cloud Provider (Useful for mixed installs with both Virtual Nodes and Bare Metal Nodes), change the `provider: ` to `none` in all.yaml.
   ```
   config:
     provider: none
     base_domain: example.com
     ...
   ```
9. If you wish to enable custom NTP servers on your nodes, set `ntp.custom` to `True` and define `ntp.ntp_server_list` to fit your requirements.
   ```
   ntp:
     custom: True
     ntp_server_list:
     - 0.rhel.pool.ntp.org
     - 1.rhel.pool.ntp.org
   ```
10. Network Policy is enabled by default.  To use Multitenant or Subnet, change isolationMode
    ```
    isolationMode: Multitenant
    ```
> Step **#5** needn't exist at the time of running the setup/installation step, so provide an accurate guess of where and at what context path **bootstrap.ign** will eventually be served

### Set Ansible Inventory and Configuration

Now configure `ansible.cfg` and `staging` inventory file based on your environment before picking one of the 5 different install options listed below.

#### Update the `staging` inventory file  
Under the `webservers.hosts` entry, use one of two options below :
   1. **localhost** : if the `ansible-playbook` is being run on the same host  as the webserver that would eventually host bootstrap.ign file
   2. the IP address or FQDN of the machine that would run the webserver.

#### Update the `ansible.cfg` based on your needs

* Running the playbook as a **root** user
  * If the localhost runs the webserver
      ```
      [defaults]
      host_key_checking = False
      ```
  * If the remote host runs the webserver
      ```
      [defaults]
      host_key_checking = False
      remote_user = root
      ask_pass = True
      ```
* Running the playbook as a **non-root** user
  * If the localhost runs the webserver
      ```
      [defaults]
      host_key_checking = False

      [privilege_escalation]
      become_ask_pass = True
      ```
  * If the remote host runs the webserver
      ```
      [defaults]
      host_key_checking = False
      remote_user = root
      ask_pass = True

      [privilege_escalation]
      become_ask_pass = True
      ```

### Run Installation Playbook
```sh
# Option 1: DHCP + use of OVA template
ansible-playbook -i staging dhcp_ova.yml

# Option 2: DHCP + PXE boot
ansible-playbook -i staging dhcp_pxe.yml

# Option 3: ISO + Static IPs
ansible-playbook -i staging static_ips.yml

# Refer to restricted.md file for more details
# Option 4: DHCP + use of OVA template in a Restricted Network
ansible-playbook -i staging restricted_dhcp_ova.yml

# Option 5: Static IPs + use of ISO images in a Restricted Network
ansible-playbook -i staging restricted_static_ips.yml

# Option 6: Static IPs + use of OVA template
# Note: OpenShift 4.6 or higher required
ansible-playbook -i staging static_ips_ova.yml

# Option 7: Static IPs + use of OVA template in a Restricted Network
# Note: OpenShift 4.6 or higher required
ansible-playbook -i staging restricted_static_ips_ova.yml
```

### Miscellaneous
* If you are re-running the installation playbook make sure to blow away any existing VMs (in `ocp4` folder) listed below:  
  1. bootstrap
  2. masters
  3. workers
  4. `rhcos-vmware` template (if not using the extra param as shown below)
* If a template by the name `rhcos-vmware` already exists in vCenter, you want to reuse it and  skip the OVA **download** from Red Hat and **upload** into vCenter, use the following extra param.

   ```sh
   -e skip_ova=true
   ```

* If you would rather want to clean all folders `bin`, `downloads`, `install-dir` and re-download all the artifacts, append the following to the command you chose in the first step
   ```sh
   -e clean=true
   ```
### Expected Outcome

1. Necessary Linux packages installed for the installation
2. SSH key-pair generated, with key `~/.ssh/ocp4` and public key `~/.ssh/ocp4.pub`
3. Necessary folders [bin, downloads, downloads/ISOs, install-dir] created
4. OpenShift client, install and .ova binaries downloaded to the **downloads** folder
5. Unzipped versions of the binaries installed in the **bin** folder
6. In the **install-dir** folder:
   1. append-bootstrap.ign file with the HTTP URL of the **boostrap.ign** file
   2. master.ign and worker.ign
   3. base64 encoded files (append-bootstrap.64, master.64, worker.64) for (append-bootstrap.ign, master.ign, worker.ign) respectively. This step assumes you have **base64** installed and in your **$PATH**
7. The **bootstrap.ign** is copied over to the web server in the designated location
8. A folder is created in the vCenter under the mentioned datacenter and the template is imported
9. The template file is edited to carry certain default settings and runtime parameters common to all the VMs
10. VMs (bootstrap, master0-2, worker0-2) are generated in the designated folder and (in state of) **poweredon**

## Final Check:

If everything goes well you should be able to log into all of the machines using the following command:

```sh
# Assuming you are able to resolve bootstrap.ocp4.example.com on this machine
# Replace the bootstrap hostname with any of the master or worker hostnames
ssh -i ~/.ssh/ocp4 core@bootstrap.ocp4.example.com
```

Once logged in, on **bootstrap** node run the following command to understand if/how the masters are (being) setup:

```sh
journalctl -b -f -u bootkube.service
```

Once the `bootkube.service` is complete, the bootstrap VM can safely be `poweredoff` and the VM deleted. Finish by checking on the OpenShift with the following commands:

```sh
# In the root folder of this repo run the following commands
export KUBECONFIG=$(pwd)/install-dir/auth/kubeconfig
export PATH=$(pwd)/bin:$PATH

# OpenShift Client Commands
oc whoami
oc get co
```
### Debugging

To check if the proxy information has been picked up:
```sh
 # On Master
 cat /etc/systemd/system/machine-config-daemon-host.service.d/10-default-env.conf

 # On Bootstrap
 cat /etc/systemd/system.conf.d/10-default-env.conf
 ```
To check if the registry information has been picked up:
```sh
# On Master or Bootstrap
cat /etc/containers/registries.conf
cat /root/.docker/config.json
```
To check if your certs have been picked up:
```sh
# On Master
cat /etc/pki/ca-trust/source/anchors/openshift-config-user-ca-bundle.crt

# On Bootstrap
cat /etc/pki/ca-trust/source/anchors/ca.crt
```


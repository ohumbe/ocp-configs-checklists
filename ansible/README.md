# Standalone Non-Production Quay for Disconnected OpenShift 4 Installation

This repository provides a playbook that will deploy a standalone instance of Quay using local storage on the container host.  It was written with the intention of using it as disconnected registry for installing OpenShift 4 so it also includes playbooks to mirror OpenShift content to this repository.  However, one can leverage just the Quay setup portion in order to work just with Quay itself.

> This repo is most ideal for Home Lab and Proof-of-Concept scenarios. All work for setting up Quay is based on the documentation located [here](https://access.redhat.com/documentation/en-us/red_hat_quay/3.4/html/deploy_red_hat_quay_for_proof-of-concept_non-production_purposes/index).

## Infrastructure Prerequisites

1. Host running podman to run Quay (this host can be connected or disconnected)
> Tested with:
>  * podman 2.2.1
>  * RHEL 8.3
2. Approximately 20G disk space available on host running Quay
> This should be sufficient space to mirror one release version of OpenShift 4 to Quay.  More space will be required to mirror additional versions and/or mirror operators.

## Disconnected Prerequisites

1. If Quay will be running on a disconnected host, the required images for Postgresql, Redis, and Quay must be pre-loaded into the local podman registry.

On an internet connected host:
```
podman login registry.redhat.io
podman pull registry.redhat.io/rhel8/postgresql-10:1
podman save registry.redhat.io/rhel8/postgresql-10:1 > /tmp/postgresql.tar 
podman pull registry.redhat.io/rhel7/redis-5:1
podman save registry.redhat.io/rhel7/redis-5:1 > /tmp/redis.tar
podman pull registry.redhat.io/quay/quay-rhel8:v3.4.3
podman save registry.redhat.io/quay/quay-rhel8:v3.4.3 > /tmp/quay.tar
```
Transfer the tar files to the disconnected host that will run Quay
```
podman load -i /path/to/postgresql.tar
podman load -i /path/to/redis.tar
podman load -i /path/to/quay.tar
```

2. If Quay will be running on a disconnected host, the bundle file created using `ocp-mirror-connected.yml` must already be transferred to the disconnected registry.

3. Your pullsecret from [https://cloud.redhat.com](https://cloud.redhat.com) must exist on the registry host as defined in `cloud_secret`.

## Setup
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
* OpenShift mirror variables
> Pre-populated entries are set in **mirror-vars.yml** and are ready to be used.  However, the values should be customized to your particular environment.  These variables are used for downloading and building the disconnected registsry tar file and for populating the disconnected registry itself.
1. `bin_dir`: Where to install `oc` and `openshift-install`
2. `bundle_file`: Where bundle file is created to be transferred to disconnected registry host
                  Where bundle file is located on disconnected registry host
3. `removable_media_path`: Where temporary images are downloaded to create bundle file to transfer
                           Where the bundle file is extracted on disconnected registry host
4. `ocp_release`: x.y.z for OpenShift release to mirror
5. `local_repository`: namespace/repository in Quay to mirror *(**must already exist**)*
6. `cloud_secret`: full path for pullsecret from [https://cloud.redhat.com](https://cloud.redhat.com)
7. `merged_secret`: full path for merged pullsecret (cloud+disconnected_registry)
8. `disconnected_registry_user`: your quay user
9. `disconnected_registry_pass`: your quay password

* Quay registry variables
1. `base_dir`: A filesystem with at least 20G free for all Quay data to be stored.
> OPTIONAL: customize subdirectory names for Quay components and/or local pull secret
2. `registry_fqdn`: Container hostname (or an approriate alias)
3. `registry_ip`: IP of your container host
4. `#postgresql_ip`: Uncomment to use an IP different from `registry_ip`
> When testing on a container host running on VMware, quay could no communicate with postgresql without using the IP of the postgresql container.  In this case, set an IP address for postgresql to this variable to ensure the container always uses the same IP so the Quay config is always valid. (podman on RHEL 8 uses 10.88.0.x as the default container network)
5. `#redis_ip`: Uncomment to use an IP different from `registry_ip`
> When testing on a container host running on VMware, quay could no communicate with redis without using the IP of the redis container.  In this case, set an IP address for redis to this variable to ensure the container always uses the same IP so the Quay config is always valid. (podman on RHEL 8 uses 10.88.0.x as the default container network)
6. `quay_host_connected`: Set true|false if container host is internet-connected
> When set to ***true***, `required_pkgs` will be checked/installed and postgresql, redis, and quay containers will pull from registry.redhat.io.  When set to ***false***, postgresql, redis, and quay must be pre-loaded in the local podman registry.
7. `quay_port`: Set to desired SSL port


## Basic workflow
The `quay-setup.yml` playbook can be run at any time, and this will typically only be run once.  Mirroring the OpenShift release images will be a two-stage operation.  First, run the `ocp-mirror-connected.yml` playbook.  This will create a tar file at `{{ bundle_file }}`.  Next, the tar.gz file should be transferred to `{{ bundle_file }}` on the disconneted registry host.  Ensure that the registry host has already been configured with a username/password and the namespace/reposistory with approarite write permissions exists as defined in `mirror-vars.yml`.  Finally, the `ocp-mirror-disconnected.yml` playbook should be run on the disconnected registry.host.
> NOTE: For test environments, the disconnected registry host does not have to actually be disconnected and may actually be the same host used to do the initial mirror to disk.

### Quay Registry Setup
`ansible-playbook quay-setup.yml -e host=<registry_host>`
> Substitute \<registry_host\> for your registry host as identified in your inventory

1. Check for and install required packages as required
2. Setup and configure directories for Quay
3. Configure firewall if running
4. Create a self-signed SAN certificate
5. Create and start Postgresql container as required
6. Create and start Redis container as required
7. Create and start Quay container as required

### OpenShift image mirror disk
`ansible-playbook ocp-mirror-connected.yml -e host=<registry_host>`
> Substitute \<registry_host\> for your registry host as identified in your inventory.
> This ***must*** run on an internet connected host.

1. Setup directories for downloaded data
2. Download binaries for OpenShift release being mirrored
3. Install binaries on host system
4. Sync images to local directory
5. Create tar of images and binary downloads for transfer to disconnected registry host
6. OPTIONAL: Transfer to disconnected registry host if required

### OpenShift image mirror to registry
1. Extract the transferred bundle
2. Install OpenShift binaries: oc, openshit-install
3. Create merged pull-secret including disconnected registry credentials
4. Sync OpenShift images from disk to registry

## TODO
Update `ocp-mirror-disconnected.yml` to include API calls to potentially create initial username/password and initial namespace/repoistory.

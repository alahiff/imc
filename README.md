# IMC

*** Moved to https://github.com/prominence-eosc/imc ***

## Overview

It is frequently assumed that when you're using a cloud you have access to an essentially infinite amount of resources, however this is not always the case. IMC is for situations when you have access to many small clouds and you need a tool which can deploy and configure virtual infrastructure across them.

Features include:
* selection of clouds which meet specified requirements
  * e.g. I want to deploy a CentOS 7 VM with at least 8 cores and 32 GB of RAM
* clouds are ranked based on specified preferences
  * e.g. I would prefer my VMs to be deployed on my local private cloud, but if that is full try my national research cloud, but if that is also full then use a public cloud
* if deployment on a cloud fails, another cloud will be automatically tried, and the cloud which failed will temporarily be blacklisted
* many types of failures and issues are handled automatically, including:
  * deployment failing completely
  * contextualization failure
  * infrastructure taking too long to deploy
* VM flavour selection can be selected based on cost for the case of a public cloud
* clouds can be grouped into regions

IMC uses [Infrastructure Manager](https://github.com/grycap/im) to deploy and configure infrastructure on clouds, including OpenStack, AWS, Azure and Google Compute Platform. It can use either Ansible or Cloud-Init for contextualization. [Open Policy Agent](https://www.openpolicyagent.org) is used for making decisions about what clouds, VM flavours and images to use.

![Architecture](imc.png)

IMC allows for hierarchical cloud bursting. A simple example would be to burst from a single local private cloud to an external private cloud and then to burst from the external private cloud to a public cloud.

![Hierarchical cloud bursting](cloudbursting.png)

A more complex example is shown below. In this case, once the local cloud is full, new infrastructure will be deployed on clouds in the "national" region. Once these are full any new infrastructure will be deployed in clouds in the "Europe" region. And finally if these also become full clouds in the "public" region will be used.

![Hierarchical cloud bursting with regions](hcb-regions.png)

## Configuration
A JSON document in the following form is used to provide static information about known clouds to OPA:
```json
{
   "clouds":{
       "cloud1":{...},
       "cloud2":{...},
       ...
       "cloudn":{...}    
   }
}
```
Configuration for a single cloud has the form:
```json
{
   "name":"<name>",
   "region":"<region>",
   "quotas":{
       "cores":i,
       "instances":j
   },
   "images":{
       "<id>":{
           "name":"<name>",
           "architecture":"<arch>",
           "distribution":"<dist>",
           "type":"<type>",
           "version":"<version>"
        }   
   },
   "flavours":{
       "<id>":{
           "name":"<name>",
           "cores":i,
           "memory":j,
           "tags":{
           },
       } 
   }
}
```
The image name should be in a form directly useable by IM, for example `gce://europe-west2-c/centos-7` (for Google) or `ost://<openstack-endpoint>/<id>` (for OpenStack). Meta-data is provided for each image to easily enable users to select a standard Linux distribution image at any site, e.g. CentOS 7 or Ubuntu 16.04, without needing to know in advance the image name at each site.

Each flavour has an optional `tags`, which should contain key-value pairs. This can be used to specify additional information about the VM flavour, for example:
```json
"tags":{
    "infiniband":"true"
}
```
Tags can be taken into account with requirements and preferences.

An example clouds configuration file is provided: `policies/clouds.json`.

## Deployment
Deploy Infrastructure Manager following the instructions https://github.com/grycap/im. Alternatively an existing deployment can be used. For testing it is adequate to run the IM Docker container:
```
docker run -d --name=im -p 127.0.0.1:8899:8899 grycap/im:1.7.4
```

Deploy Open Policy Agent:
```
docker run -p 127.0.0.1:8181:8181 -v <directory>:/policies --name=opa -d openpolicyagent/opa:latest run --server /policies
```
where `<directory>` should be replaced with the path to the directory on the host containing the policy and data files (i.e. the contents of https://github.com/alahiff/imc/tree/master/policies).

Deploy the IM client. The simplest way to do this is using pip:
```
pip install IM-client==1.5.1
```
It is important to note that 1.5.2 and 1.5.3 cannot be used as they return incorrect exit codes.

In the home directory of the user which will run IMC, create a file `.im_client.cfg`:
```
[im_client]
xmlrpc_url=http://localhost:8899
auth_file=/home/cloudadm/.im_auth.dat
```
This should be adjusted as necessary to point to the IM XML-RPC service and to the IM client authorization file, which should list all required clouds. See http://www.grycap.upv.es/im/documentation.php for information on what should appear in this file.

## RADL files

IM uses Resource and Application Description Language (RADL) files to describe the infrastructure to be deployed. IMC must be provided with a RADL file, noting that:
* `${image}` will be replaced with the disk image name (essential)
* `${instance}` will be replaced with the instance type (essential)
* `${cloud}` will be replaced with the name of the cloud

## Usage

Some example RADL files are located in the examples directory.

### Deploying a single VM
Using the RADL file `one-node.radl` deploy an 8 core VM with 8 GB memory running CentOS 7 on a FedCloud site:
```
imc.py --cores=8 \
       --memory=8 \
       --image-arch x86_64 \
       --image-dist centos \
       --image-type linux \
       --image-vers 7 \
       --require-region FedCloud \
       one-node.radl
```
Example output:
```
Found 1 instances to deploy
Suitable clouds = [INFN-PADOVA-STACK,RECAS-BARI,CESNET-MetaCloud,IN2P3-IRES]
Attempting to deploy on cloud "INFN-PADOVA-STACK" with image "appdb://INFN-PADOVA-STACK/egi.centos.7?fedcloud.egi.eu" and flavour "4"
Created infrastructure with id a58b2dea-c755-11e8-a9a6-0242ac110002 on cloud INFN-PADOVA-STACK and waiting for it to be configured
Infrastructure is in state unconfigured
Infrastructure is unconfigured, will try reconfiguring once after writing contmsg to a file
Infrastructure has been unconfigured too many times, so destroying after writing contmsg to a file
Attempting to deploy on cloud "RECAS-BARI" with image "appdb://RECAS-BARI/egi.centos.7?fedcloud.egi.eu" and flavour "10"
Created infrastructure with id fafc69a6-c755-11e8-8fa3-0242ac110002 on cloud RECAS-BARI and waiting for it to be configured
Infrastructure is in state running
Infrastructure is in state configured
Successfully configured infrastructure with id fafc69a6-c755-11e8-8fa3-0242ac110002 on cloud RECAS-BARI
```
Here we see that deployment initially failed, but it was successfully deployed on the second cloud tried.

### Deploying a SLURM cluster
In this example deployment was successful on the first attempt:
```
$ /usr/local/bin/imc.py --image-arch x86_64 --image-dist centos --image-type linux --image-vers 7 --cores=4 --memory=4 --require-region FedCloud slurm.radl
Found 1 instances to deploy
Suitable clouds = [CESNET-MetaCloud,IN2P3-IRES,INFN-PADOVA-STACK,RECAS-BARI]
Attempting to deploy on cloud "CESNET-MetaCloud" with image "appdb://CESNET-MetaCloud/egi.centos.7?fedcloud.egi.eu" and flavour "large"
Created infrastructure with id f54b0360-c759-11e8-afad-0242ac110002 on cloud CESNET-MetaCloud and waiting for it to be configured
Infrastructure is in state running
Infrastructure is in state configured
Successfully configured infrastructure with id f54b0360-c759-11e8-afad-0242ac110002 on cloud CESNET-MetaCloud
```
In this example deployment on two clouds failed:
```
[cloudadm@vnode-0 imc]$ /usr/local/bin/imc.py --image-arch x86_64 --image-dist centos --image-type linux --image-vers 7 --cores=4 --memory=4 --require-region FedCloud slurm.radl
Found 3 instances to deploy
Suitable clouds = [IN2P3-IRES,INFN-PADOVA-STACK,RECAS-BARI,CESNET-MetaCloud]
Attempting to deploy on cloud "IN2P3-IRES" with image "appdb://IN2P3-IRES/egi.centos.7?fedcloud.egi.eu" and flavour "4"
Infrastructure creation failed
Connected with: http://localhost:8899

Traceback (most recent call last):
  File "/usr/local/bin/im_client.py", line 363, in <module>
    print("ERROR creating the infrastructure: %s" % inf_id)
UnicodeEncodeError: 'ascii' codec can't encode character u'\xe9' in position 133: ordinal not in range(128)

Attempting to deploy on cloud "INFN-PADOVA-STACK" with image "appdb://INFN-PADOVA-STACK/egi.centos.7?fedcloud.egi.eu" and flavour "3"
Created infrastructure with id 8455e212-c79d-11e8-90cb-0242ac110002 on cloud INFN-PADOVA-STACK and waiting for it to be configured
Infrastructure is in state failed
Infrastructure creation failed, so destroying
Attempting to deploy on cloud "RECAS-BARI" with image "appdb://RECAS-BARI/egi.centos.7?fedcloud.egi.eu" and flavour "9"
Created infrastructure with id c8787f86-c79d-11e8-8165-0242ac110002 on cloud RECAS-BARI and waiting for it to be configured
Infrastructure is in state pending
Infrastructure is in state running
Infrastructure is in state configured
Successfully configured infrastructure with id c8787f86-c79d-11e8-8165-0242ac110002 on cloud RECAS-BARI
```
The first cloud failing gave an error message in French which confused IM client. IMC prints the stdout/err to the screen (and to the log file) when creation fails as it can be useful for debugging.

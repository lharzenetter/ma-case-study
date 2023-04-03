# An Integrated Management System

This setup guide provides you with instructions to run the case study of the SNCS Paper [An Integrated Management System for Composed Applications Deployed by Different Deployment Automation Technologies]().

The case study sets up an instance of the sock shop microservice demo using different Deployment Technologies.
The catalogue microservice is deployed onto an VM running Ubuntu 22.04. The Instance is created using Terraform, while the components of the catalogue service are installed onto the instance using Puppet.
All other microservices that make up the sock shop are deployed onto a local Kubernetes Cluster using Docker Desktop.

Using the [TOSCin](https://github.com/UST-EDMM/edmm/tree/master/TOSCin) Framework, an instance model of the sock shop instance can be derived and used to manage the sock shop instance with the OpenTOSCA ecosystem.
Note that this guide assumes that you have a running OpenTOSCA ecosystem, including [Winery](https://github.com/OpenTOSCA/winery) and the [OpenTOSCA Container](https://github.com/OpenTOSCA/container).



## Setup the Sockshop

This section describes how the Sockshop can be deployed using Terraform, Puppet, and Kubernetes.

### Setup the Puppet Primary Server

Setup a VM running Ubuntu 22.04 on any platform you like.
As the Puppet agent will be running on a VM, ensure that your secuirty settings allow the Puppet Primary Server to accept incoming connections from the Puppet Agent.
Make the VM available via DNS/IP so that the Puppet Agent can later connect to the Primary Server.

**NOTE**: You can either run the script [puppetmaster.sh](./puppetmaster.sh) or follow [this guide](https://github.com/UST-EDMM/edmm/blob/master/TOSCin/readme.md).
> When running the script, you **MUST** enter the password to the puppetdb manually when prompted!!

```shell script
chmod +x ./puppetmaster.sh
sudo -E IP=2.2.1.1 puppetDNS=puppet-master.test.com ./puppetmaster.sh
```

The script currently only runs on Ubunbtu 20.04. 22.04 is not yet supported by Puppet and Postgres


As the Puppet Primary server is now operational, you can upload the configuration files from [puppet-master-environment](puppet-master-environment) to the primary server.
First replace the node selector in the [Manifest](puppet-master-environment/manifests/site-aws.pp) with the cert name you later intend to specifiy for the Puppet Agent Node.
Then, simply copy all directories and files from [puppet-master-environment](puppet-master-environment) to `/etc/puppetlabs/code/environments/production`.





### Setup the Puppet Agent on AWS

The catalogue microservice is deployed on an EC2 Instance in the AWS cloud.
First create a EC2 security group that allows incoming traffic for SSH (port 22) and HTTP-ALT (port 8080).
Also create a key pair with a custom name.

As Puppet is used to configure the created instance, first prepare the [./puppet-agent-setup/puppet-setup.yaml](./puppet-agent-setup/puppet-setup.yaml) file.
The file contains cloud-init directives and is specified as user data for the EC2 instance.
It ensures that Puppet is installed on the EC2 instance after launch and that a catalogue-user is created that is used to run the catalogue microservice.
Replace the example values for `*conf.agent.server*` and `*conf.agent.certname*` with valid values for your setup.
The `*conf.agent.server*` property MUST be a resolveable DNS name under which your Puppet Primary Server is available.
The `*conf.agent.client*` property MUST equal the node selector you used previously when setting up the environment in the primary server.
However, the EC2 instance does not need to be accessible via DNS.
The prototype solely relies on IP addresses.

You can either use Terraform or AWS CloudFormation to create the EC2 instance.
For both technologies a configuration file is provided: [Terraform file](./puppet-agent-setup/main.tf) and [CloudFormation template](puppet-agent-setup/aws-cloudformation-template.json).
In both files replace the security group id and the key name with the id of the security group and the name of the key pair you created previously.
When using CloudFormation you must also replace the user data in the template with the base64 encoded content of your [puppet-setup.yaml](puppet-agent-setup/puppet-setup.yaml).
Create the instance by either running `terraform apply` or by uploading the [CloudFormation template](puppet-agent-setup/aws-cloudformation-template.json) using the AWS ManagementConsole or CLI.

Alternatively, you can install the agent using the [agent script](puppetagent.sh):

```script
sudo -E IP=[IP] PuppetMaster=[MasterIP] ./agent.sh
```

Afterwards, you have to sign the agent at the server:

```script
sudo /opt/puppetlabs/bin/puppetserver ca list
sudo /opt/puppetlabs/bin/puppetserver ca sign --certname puppet-agent
```


After the EC2 instance is running, the puppet agent is automatically installed on it and should automatically connect to the puppet primary server.
If the automatic connection fails, log in to the instance using your previously created key pair and execute the following command:

```shell script
sudo /opt/puppetlabs/bin/puppet agent --test
```

The catalogue microservice should now be running on the instance.
Check its status by executing the follwing command:

```shell script
sudo systemctl status catalogue-app
```




### Setup the Kubernetes Deployment

Download and install [Docker Desktop](https://www.docker.com/products/docker-desktop)
and [enable the included Kubernetes Cluster](https://docs.docker.com/desktop/kubernetes).
Ensure that your resulting kubeconfig file contains the content of the required certificates directly instead of linking to other files.

Deploy the other sock shop microservices by deploying the [complete-demo.yaml file](sock-shop-deployment/complete-demo.yaml):

```shell
kubectl apply -f sock-shop-deployment/complete-demo.yaml
```

Note, that some security feature on the specified containers MUST be disabled in order for the update management operation to function correctly.

## Setup Winery repository

Checkout the case-study branch of the OpenTOSCA internal definitions
repository: [feature/ma-alex](https://github.com/OpenTOSCA/tosca-definitions-internal/tree/feature/ma-alex)
Adjust the winery config file .winery/winery.yml in your home directory to use the cloned definitions repository.

## Setup AWS command line profile TOSCin

Create a AWS command line user with the following policies:
![test](aws-toscin-rights.png)

Edit the .aws/credentials file in your home directory and append the following lines with the values of the user you just created:

```
[TOSCin]
aws_access_key_id = your-access-key-id
aws_secret_access_key = your-secret-access-key
```

Edit the .aws/config file in your home directory and append the following lines:

```
[profile TOSCin]
region = eu-central-1
```

If you are using a different AWS region, adjust the value as needed.

## Setup and run TOSCin

TOSCin is currently part of the [UST-EDMM/edmm](https://github.com/UST-EDMM/edmm) repository. Checkout the master branch
of the project. All TOSCin related code is part of the [TOSCin](https://github.com/UST-EDMM/edmm/tree/master/TOSCin)
submodule.

Use the [multi-transform-config.yml](multi-transform-config.yml) from this repository as a starting point and replace
all values in brackets with the correct values for your environment, e.g. replace the username of the operating system
and the ip address of the Puppet primary server.

You can execute the TOSCin retrieval process by supplying the following command line parameters:

```
multitransform -c multi-transform-config.yml
```
![toscin runconfiguration example](toscin-runconfiguration.png)

After the execution has completed you should see the retrieved service template in your Winery installation. 


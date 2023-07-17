

#  Automate the Infrastructure and Application Deployment for Application
## Problem

Alpine Inc is currently facing challenges in deploying their Foo app effectively and efficiently. The manual deployment process is prone to human errors, leading to inconsistencies, delays, and potential issues in the production environment. These errors can range from misconfigured infrastructure components to incorrect application code deployments, causing disruptions to the app's availability and performance.

## Solution

In response to the needs of Alpine Inc, we will implement an automated deployment process that encompasses both the infrastructure and application deployment. This process will utilize EC2 Instances, leveraging the benefits of scalability and flexibility on AWS. The EC2 Instances will be provisioned and configured automatically as part of the deployment process. We will be using the docker image provided by Alpine's dev team and thereby configure the app and database containers as required.

## Justification of the solution

To implement the automation as required we will be deploying the app container on two identical EC2 Instancees behind a load balancer with the database running on a separate EC2 Instance. These EC2 Instances are configured using Ansible which implements docker containers.
As we go through the sections A-D, the deployment of EC2 Instances using terraform and configuration of EC2 Instances using Ansible is explained.

### Section A

#### Configuring Terraform 

There are three EC2 instances deployed , two for app server and one for database server. The code for the setup of these instances can be found in main.tf in infra folder. 

Two EC2 instances are defined using the aws_instance resource block named "app_server_1" and "app_server_2" respectively. The ami parameter specifies the ID of the Ubuntu Amazon Machine Image (AMI) to be used for the instances. The instance_type parameter sets the instance type to "t2.micro", which determines the hardware capabilities of the instances. The key_name parameter specifies the key pair to be used for SSH access to the instances is set using the variable block and it needs to be defined while running terraform apply. The security_groups parameter specifies the security group(s) associated with the instances. In this case, they are associated with the "vm_app" security group. The security group has two ingress rules which allows inbound SSH (port 22) and HTTP (port 80) access from any IP address. It also has two egress rules which allows outbound PostgreSQL (port 5432) and HTTPS(443) access to any IP address. This could turn out to be a security issue since access should be restricted but IP address is not defined by the team as such. It can be changed by Alpine's team as required by changing the CIDR block.
An additional EC2 instance is defined using the aws_instance resource block named "db_server". Similar to the app server instances, it uses the Ubuntu AMI, "t2.micro" instance type, and the specified key pair for SSH access. The security_groups parameter associates the instance with the "vm_db" security group. It includes includes an ingress rule allowing inbound PostgreSQL (port 5432) access from any IP address (0.0.0.0/0). There is also an egress rule allowing outbound PostgreSQL (port 5432) access to any IP address.


#### Configuring Ansible 

Firstly, we used separate playbooks which have separate purposes for to configure the EC2 Instance.  ```app-playbook.yml``` configures the dependencies required for EC2 Instance to run the application using the docker image hosted by Alpine's dev team. 

This playbook performs the following tasks to configure the app server:

- Installs the required system packages for Docker by using the apt module.
- Adds the Docker GPG apt key using the apt_key module.
- Adds the Docker repository to the system using the apt_repository module.
- Updates apt cache and installs the latest version of Docker CE using the apt module.
- Starts the app container using the community.docker.docker_container module.
- It pulls the Docker image patrmitacr.azurecr.io/assignment2app:1.0.0.
- Sets environment variables for the app container, such as the database hostname, port,     username, password, and the app's listening port.
- Publishes the container's port 3001 on the host to port 80, making the application accessible externally

Secondly, ```db-playbook.yml``` creates the database container and runs it using docker container. The SQL file which populates the database can be found in misc folder. Since we are working through Ubuntu VM, we had to first copy the SQL file from local machine to Ubuntu VM so that we can use volumes in docker to access that SQL file.

This playbook performs the following tasks to configure the database server:

- Installs the required system packages for Docker using the apt module.
- Adds the Docker GPG apt key using the apt_key module.
- Adds the Docker repository to the system using the apt_repository module.
- Updates apt cache and installs the latest version of Docker CE using the apt module.
- Copies a SQL file from the local machine to the database server using the copy module. This SQL file is used for initializing the database.
- Creates and runs the database container using the community.docker.docker_container module.
- It pulls the Docker image postgres:14.7.
- Sets environment variables for the database container, including the password, username, -  and database name.
- Publishes the container's port 5432 on the host to port 5432, allowing external access to the database.
- Binds the SQL file to the container, which will be executed during container initialization.

Lastly, ```app-server-hosts.yml ``` and ```db-server-hosts.yml``` provides the hosts for app server and database server respectively. These fields will be populated automatically when running the program through workflow or shell script as it configures to dynamically populate these files with the required IP addresses.

#### Configuring the shell script

To automate the deployment process which can be used by the dev team of alpine, a shell script has been  created which automates the  deployment process of infrastructure using Terraform and configuration management using Ansible. The script can be found in root directory of the repository ``` deploy-script.sh```

This script contains the following steps to automate the deployment process: 

- Exporting AWS Credentials:

The script starts by exporting AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN) as environment variables. These credentials are used by Terraform to authenticate with AWS and provision resources.

- Initialize and Apply Terraform for S3 Bucket and DynamoDB Table (Refer to Section C):

The script changes the directory to the terra-bucket folder and initializes Terraform using the terraform init command. Then, it applies the Terraform configuration using the terraform apply -auto-approve command. This step creates an S3 bucket and a DynamoDB table.
Initialize and Apply Terraform for Infrastructure:

- The script changes the directory to the infra folder and initializes Terraform using terraform init. It applies the Terraform configuration for infrastructure using terraform apply -auto-approve -var="public_key_file=/home/hibbaan/.ssh/github_sdo_key.pub". This step creates the EC2 instances for the app and database servers.

Note: The public_key_file should be changed by the team as per their requirements. For testing purposes my public has been used which will work only on my machine.

- Retrieve IP addresses for the Instances:

The script uses Terraform output variables to retrieve the public IP addresses of the app instances (app_instance1_public_ip and app_instance2_public_ip) and the public and private IP addresses of the database server (db_instance_public_ip and db_instance_private_ip).
Update Ansible Inventory Files:

- The script changes the directory to the ansible folder.
It overwrites the app-servers-hosts.yml file with the appropriate IP addresses for the app servers. It overwrites the db-servers-hosts.yml file with the appropriate IP address for the database server.

- Run Ansible Playbooks:

The script runs the Ansible playbooks using the ansible-playbook command. It executes the app-playbook.yml playbook with the inventory file app-servers-hosts.yml and passes the private key (--private-key ~/.ssh/github_sdo_key) for SSH authentication.
It executes the db-playbook.yml playbook with the inventory file db-servers-hosts.yml and passes the private key for SSH authentication. 

```-e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'``` argument is passed in the command to run playbooks. This removes the host checking after running ansible commands

The script automates the entire process of setting up the infrastructure and configuring the app and database servers using Terraform and Ansible, respectively. It retrieves IP addresses, updates the Ansible inventory files, and then executes the Ansible playbooks for provisioning and configuration management

## Section B

To improve the resiliency of the application, the app container is deployed on two EC2 instances behind a load balancer.
The code for load balancer's setup can be found in main.tf. For this part of the section we also had to setup VPC and subnets. The VPC and subnets used here are default data sources in the AWS Account.These data sources are used to dynamically fetch information about the default VPC and its associated subnets. This allows the Terraform code to work with the default VPC and subnets without hardcoding specific values, making the code more flexible and adaptable to different environments.


1. **Default VPC:**
   The `aws_vpc` data source is used to retrieve details about the default VPC in the AWS account.
   - `default = true` specifies that the data source should return information about the default VPC.
   - The retrieved information can be accessed using the resource name and attribute, such as `data.aws_vpc.default.id`.

2. **Default Subnets:**
   The `aws_subnets` data source is used to fetch details about the subnets associated with the default VPC.
   - A filter is applied to fetch subnets based on the VPC ID.
   - `filter` block:
     - `name = "vpc-id"` specifies that the filter should be based on the VPC ID.
     - `values = [data.aws_vpc.default.id]` provides the VPC ID retrieved from the `aws_vpc` data source as the filter value.
   - The retrieved subnet information can be accessed using the resource name and attributes, such as `data.aws_subnets.example.ids`.

These subnets are used in load balancer which will automatically assign to the EC2 instances for app servers.

The Terraform code in main.tf sets up an Application Load Balancer  in AWS and configures it to distribute incoming traffic between two EC2 instances serving as app servers. The 

1. **Creating the Load Balancer (ALB):**
   - The `aws_lb` resource defines the configuration for the ALB.
   - `name`: Specifies the name of the ALB as "my-app-lb".
   - `internal`: Specifies whether the ALB is internal or public. In this case, it is set to `false`, indicating a public ALB.
   - `load_balancer_type`: Specifies the type of the ALB as "application".
   - `subnets`: Refers to the subnets where the ALB will be deployed. The `data.aws_subnets.example.ids` variable provides the subnet IDs.
   - `security_groups`: Refers to the security group(s) associated with the ALB. Here, `aws_security_group.lb.id` represents the security group ID.

2. **Setting up the Load Balancer Listener:**
   - The `aws_lb_listener` resource defines the listener configuration for the ALB.
   - `load_balancer_arn`: Specifies the ARN (Amazon Resource Name) of the ALB created in the previous step.
   - `port`: Specifies the port number (80) on which the ALB will listen for incoming traffic.
   - `protocol`: Specifies the protocol to be used for communication, which is "HTTP" in this case.
   - `default_action`: Specifies the default action for incoming traffic that matches the listener's rules. The action type is set to "forward" and the target group ARN is provided through `aws_lb_target_group.app_tg.arn`.

3. **Configuring the Load Balancer Target Group:**
   - The `aws_lb_target_group` resource defines the configuration for the target group associated with the ALB.
   - `name`: Specifies the name of the target group as "my-app-tg".
   - `port`: Specifies the port number (80) on which the target group will forward traffic to the registered instances.
   - `protocol`: Specifies the protocol used for communication with the target instances, which is "HTTP".
   - `target_type`: Specifies the type of target instances to be registered with the target group. Here, it is set to "instance".
   - `vpc_id`: Refers to the ID of the VPC (Virtual Private Cloud) in which the target group will be created. The `data.aws_vpc.default.id` variable provides the VPC ID.

4. **Attaching Target Group to EC2 Instances:**
   - The `aws_lb_target_group_attachment` resources define the attachment of EC2 instances to the target group.
   - Two resources are defined, one for each app server instance (`app1_attachment` and `app2_attachment`).
   - `target_group_arn`: Specifies the ARN of the target group to which the instances will be attached.
   - `target_id`: Specifies the ID of the EC2 instance to be attached to the target group. The IDs `aws_instance.app_server_1.id` and `aws_instance.app_server_2.id` represent the app server EC2 instances.
   - `port`: Specifies the port number (80) on which traffic will be forwarded to the instances.

The security group for Load Balancer has 3 ingress rules which allows traffic from Port 22,80 and 443 and an egress rule to any destination.

In summary, this Terraform code provisions an ALB, sets up a listener on port 80 for incoming HTTP traffic, configures a target group to handle instances, and attaches the EC2 instances serving as app servers to the target group. This allows the ALB to evenly distribute incoming traffic across the app server instances.

## Section C

We implemented S3 bucket remote backend for state and dynamodb table in terraform instead of ClickOps which fairly normal in the industry, but in this case it's better to implement using terraform code as it's more efficient and our goal is to automate the whole process.
To implement terraform code for this part we had to make sure that s3 bucket and dynamodb table are created before running the backend configuration.

1. **Backend Configuration:**
   The `backend "local"` block specifies the backend configuration for Terraform, indicating that the state file will be stored locally. This means that the state file will be stored on the local machine where Terraform commands are executed. 

2. **S3 Bucket Creation:**
   The `aws_s3_bucket` resource defines the creation of an S3 bucket. The bucket name is specified as "s3-state-bucket-s3847243". This bucket can be used to store the Terraform state file.

3. **S3 Bucket Versioning:**
   The `aws_s3_bucket_versioning` resource enables versioning for the S3 bucket created in the previous step. Versioning allows multiple versions of objects to be stored in the bucket, providing a way to track changes and recover previous versions if needed.

4. **DynamoDB Table for State Locking:**
   The `aws_dynamodb_table` resource creates a DynamoDB table named "state-lock". This table is used for Terraform state locking, which prevents concurrent modifications to the state file. The table has a hash key named "LockID" of type "S" (string). The `read_capacity` and `write_capacity` parameters specify the provisioned capacity for the table, and in this case, both are set to 20.
5. **Backend Configuration in main.tf**
   The backend is also configured in main.tf which runs the ec2 instances. The backend block in the Terraform configuration (main.tf in infra dir) specifies the backend configuration, which determines where the Terraform state file is stored. In this case, the backend is configured to use Amazon S3 for storing the state file and DynamoDB for state locking. 

Overall, this Terraform code sets up the necessary infrastructure components for managing the Terraform state file, enabling versioning for the S3 bucket, and creating a DynamoDB table for state locking.

## Section D

A GitHub Actions workflow has been implemented which deploys the infrastructure and runs the application it.

The workflow has been split into three jobs: terraform-s3-bucket, terraform-main and ansible.

Whenever the main branch is modified, the github actions workflow runs. This was implemented using the ``` on: push: branches: -main``` at the start of the workflow script. The GitHub Actions workflow can also be triggered via the GitHub Actions REST API. This was implemented using ``` working_dispatch```. A POST Request can be made to the GitHub Actions which will manually trigger the Github Actions workflow. To run the workflow through REST API the user must get a personal access token from Github/settings/tokens. Using the personal access token,repo name, username we can send a POST request to run it through REST API.


- Handling Credentials in GitHub Actions
To handle the credentials, we use GitHub Secrets which is added under Settings tab on GitHub. This allows to keep the credentials secured and also makes it easy to access them through our workflow by using ``` {{secrets.<SECRET_NAME}}```. AWS credentials includes AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and AWS_SESSION_TOKEN which we can get from our AWS Account. We also added the PUBLIC_KEY_FILE and SSH_PRIVATE_KEY which is used to run terraform and ansible respectively. 

- Jobs in Workflow
As mentioned before, s3 bucket and dynamodb table needs to created prior to creating the EC2 Instances since that uses s3 bucket for storing the state. Hence we run terraform-s3-bucket which initalizes and terraform and runs terraform apply which creates the s3 bucket followed by dynamodb table. This will now be used by our main.tf which will create the EC2 Instances and also deploy a load balancer. This is done under terraform-main job which will initalize terraform in an another directory and also configure AWS credentials which can be accessed through GitHub Secrets. We also create a temporary public key file using the PUBLIC_KEY_FILE key from Github Secrets since we need to pass the public key to generate the key pair in aws_key_pair resource block. Our final job would be to run our ansible playbooks which configures the EC2 Instances with necessary independencies. To run this successfully we had to use terraform output in terraform-main job to get the necessary IP Addresses and then store them in outputs which are then accessed in ansible job. We rewrite the app-server-hosts and db-server-hosts file in one of the steps in ansible job which updates the files with appropriate IP addresses to be used obtained from terraform-main outputs. Lastly, using the SSH_PRIVATE_KEY secret from github secrets, we create a temporary private key to be used in our ansible commands.

- Re-running the workflow is a no-op
We can ensure that whenever the infrastructure is deployed then re-running is a no-op from our terraform code configuration. Since the state bucket is already deployed once, it can't be recreated with the same name since the s3 bucket name has to be unique. This would throw an error in the github workflow saying that the bucket of the same name has been created. 
So in our github workflow when we add ```|| true``` to terraform apply command, this will skip through the errors to successfully pass the job in github workflow. As for our terraform-main, we do not need to do anything extra since re-running terraform apply on ec2 instances wouldn't affect any part of the infrastructure naturally and so is the case with Ansible playbooks.


## Diagrams 

<img src="/img/process.png" style="height: 900px;"/>

The Process diagram above depicts the deployment process through Github Actions workflow and using deply-script.sh.

<img src="/img/infra.jpg" style="height: 900px; width: 1200px"/>

The Infrastructure diagram depicts how each service is connected across the infrastructure including the use docker containers.

## Limitations

- It is required by the Alpine's team to update the credentials in github secrets especially the github public and private key.
- As for the CIDR blocks in security groups, any IP address is given access which needs to be modified as per Alpine's team requirements.


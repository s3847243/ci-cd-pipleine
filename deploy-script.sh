#!/bin/bash

# Set environment variables for AWS credentials - needs to be updated as per user's aws credentials
export AWS_ACCESS_KEY_ID=ASIAYKMZSKO66H7OBSPZ
export AWS_SECRET_ACCESS_KEY=IOGi/+riZ2QONgA8+zDtzH3XLyygjb9MDw8vYaEh
export AWS_SESSION_TOKEN=FwoGZXIvYXdzENP//////////wEaDDhTkS/8WIecfAlaSCLNAbNZS7tWx18DSLnDzoF6Md1ZzuQeWAkL763aFargPiRjYglxc/vq2PWSg+zU5kGPboZeszIofGdCewGgYc/jmoKxFlwtg6hLmmTr4eDEeATZxJn6+00+cQas/zPZvjhsrGtDFLifJzG69AnkxBBfYXZlwkUOBfD2x88oQjb5nZU767Dl4q3d25XxlXHd8wfM/uCxUh5WAeryQxpftYn6fi1ioEBmVRoJh4HZlCkf5vSMNKzRXocyBjVUS4P0LqT1mz0FuJGysmNZsqaTJwMo7Ky3owYyLSQ0+GkJ5MxW5i9QxgIxaa460YBA6jaMCY1cRhtT7CkKsjJrvGCsN0uwFmVPDg==

# Initialize Terraform to initialize s3 bucket and dynamoDB Table
cd terra-bucket
terraform init

# Apply Terraform to implement s3 bucket and dynamoDB Table
terraform apply -auto-approve

# Initialize Terraform for infra directory 
cd ../infra
terraform init

# Apply Terraform for infra to implement instances and pass the public key as an arg
terraform apply -auto-approve -var="public_key_file=/home/hibbaan/.ssh/github_sdo_key.pub"


# Get public address for app instance 1
app_instance1_public_ip=$(terraform output app_instance1_public_ip)

# Get public address for app instance 2 
app_instance2_public_ip=$(terraform output app_instance2_public_ip)

# Get public and private IP addresses for db_server
db_instance_public_ip=$(terraform output db_instance_public_ip)

db_instance_private_ip=$(terraform output db_instance_private_ip)


cd ../ansible
# Rewrite the server-hosts and app-playbook with necessary ip addresses 
echo "app_servers:" > app-servers-hosts.yml
echo "  hosts:" >> app-servers-hosts.yml
echo "    app1:" >> app-servers-hosts.yml
echo "      ansible_host: $app_instance1_public_ip" >> app-servers-hosts.yml
echo "    app2:" >> app-servers-hosts.yml
echo "      ansible_host: $app_instance2_public_ip" >> app-servers-hosts.yml
echo "  vars:" >> app-servers-hosts.yml
echo "      DB_PRIVATE_IP: $db_instance_private_ip" >> app-servers-hosts.yml

echo "db_servers:" > db-servers-hosts.yml
echo "  hosts:" >> db-servers-hosts.yml
echo "    db1:" >> db-servers-hosts.yml
echo "      ansible_host: $db_instance_public_ip" >> db-servers-hosts.yml


# Run Ansible playbooks
ansible-playbook app-playbook.yml -i app-servers-hosts.yml --private-key ~/.ssh/github_sdo_key -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'

ansible-playbook db-playbook.yml -i db-servers-hosts.yml --private-key ~/.ssh/github_sdo_key -e 'ansible_ssh_common_args="-o StrictHostKeyChecking=no"'

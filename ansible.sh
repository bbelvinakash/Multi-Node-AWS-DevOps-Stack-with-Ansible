#!/bin/bash
apt update -y
apt install -y python3 python3-pip git
apt install -y ansible 
pip3 install  boto3 botocore
ansible-galaxy collection install amazon.aws
mkdir -p /home/ubuntu/.ssh
cat <<KEY > /home/ubuntu/.ssh/aws-key.pem
${private_key}
KEY
chmod 400 /home/ubuntu/.ssh/aws-key.pem
chown ubuntu:ubuntu /home/ubuntu/.ssh/aws-key.pem
mkdir -p /home/ubuntu/ansible
cat <<EOF> /home/ubuntu/ansible/ansible.cfg
[defaults]
inventory = /home/ubuntu/ansible/aws_ec2.yaml
host_key_checking = False
remote_user = ubuntu
private_key_file = ~/.ssh/aws-key.pem
EOF

cat <<EOF> /home/ubuntu/ansible/aws_ec2.yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1

keyed_groups:
  - key : tags.Role
    prefix : Role

hostnames:
  - public-ip-address

compose:
  ansible_host: public_ip_address
EOF
chmod 644 /home/ubuntu/ansible/aws_ec2.yml
chmod 644 /home/ubuntu/ansible/ansible.cfg
chown -R ubuntu:ubuntu /home/ubuntu/ansible

#! /bin/bash
set -x
set -euxo pipefail
sudo yum update -y
sudo amazon-linux-extras install docker
sudo yum install docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo chkconfig docker on
sudo docker run --name nginx -v /etc/nginx/nginx.conf:/etc/nginx/nginx.conf --restart always -p 80:80 -d nginx
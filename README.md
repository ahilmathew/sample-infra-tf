# Infra Setup with Terraform

This code base sets up an infrastructure on AWS using Terraform. As part of the deploy, Nginx is also deployed and configured on the EC2 instance.
This code base also deploys a NodeJS-Express application that delivers the health check and resource usage of the `nginx` docker container via Rest API.

### Infrastructure Components
The infrastructure on AWS has the below components.
* A VPC
* A Subnet on a Single Availability Zone(defaults to us-west-2a)
* An internet gateway and associated route table and routes
* A Security group that allows HTTP access to the EC2 instance on Port 80.
* An EC2 instance(defaults to t2.micro)

### Application Components

* A health check script that runs every 10 seconds.
    * It checks if the nginx server is responding to requests on port 80.
    * It collects the resource usage of the `nginx` docker container.
    * Both of the health check outputs are stored in `/etc/resource.log`.
* A simple REST API app with NodeJS and Express.
    * This application serves the file `/etc/resource.log` created by the above health check script on `<ec2_public_ipv4_dns>/logs` via the nginx proxy.

## How to deploy

### Pre-requisites

* [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).
* AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY (This should be either given as an input to terraform while deploying or should be exported as environment variables).
    * This can also be configured in a file with `.tfvars` extension in this project directory.
* A AWS private key(*.pem) downloaded.

### Deploy Steps

* From the project root directory run `terraform apply`. This start the deploy and should ask you to input the required variables.
    * You can provide the values according to the prompts or provide variables on command line or create a file with `.tfvars` extension. [Offical Guide](https://www.terraform.io/docs/configuration/variables.html#variables-on-the-command-line)
    ``` bash
    $ terraform apply -var-file secrets.tfvars # OR
    $ terraform apply -var="aws_access_key=AXXXXXXXXXAA" -var="aws_secret_key=xxxxxxxxxxxx"  -var="aws_region=ap-southeast-2"
    ```
* After `terraform` has completed the deploy, the console should show an `application_url` as an output.

### Using the REST API to search the log file

The Node App exposes a REST API to view the `resource.log` file generated by the health check script. This log has the health check status of the `nginx` service on port `80` and the resource usage of the `nginx` docker container.

The REST API allows you to search for data inside the `resource.log`. Think of this as doing `grep` on the `resource.log` file from your web browser.
The query key that you should use for this is, `grep`. You should be able to use any flags as you would normally use while using the `grep` tool in linux.

Examples:

    `http://ec2.us-west-2.compute.amazonaws.com/logs?grep=nginx`
    `http://ec2.us-west-2.compute.amazonaws.com/logs?grep=-A1 -B1 HTTP`

### Terraform Variables

The below table shows the variables you should set/can override.
| Variable   |      Description      |  Required/Optional |
|----------|:-------------:|------:|
| `aws_access_key` |  `AWS_ACCESS_KEY` for your AWS account | Required |
| `aws_secret_key`|    `AWS_SECRET_ACCESS_KEY` for your AWS account   |  Required |
| `aws_region` | AWS region where you want to deploy the infrastructure |   Required |
| `key_name` | Name of your EC2 Key Pair |   Required |
| `key_path` | Local path for your EC2 key pair |   Required |
| `availability_zone` | AWS Availability Zone |   Optional(Defaults to `us-west-2a`) |
| `ingress_cidr` | Ingress CIDR for your EC2 Security Group |   Optional(Defaults to the whole internet `0.0.0.0/0`) |
| `instance_type` | EC2 instance type | Optional(Defaults to `t2.micro`) |

## Application Risks

* The NodeJS Application uses `child_process` which allows the application to execute shell commands on the host.
* The REST API basically allows user to run shell commands on the host which can be used in malicious ways.

## Future Improvements

* Write a full fleged text file parser to serve the data via REST API instead of executing commands on the host machine.
* Host the EC2 instance on private subnet and allow access to the external world via a application load balancer.
* Host EC2 instances on different availability zones to ensure High Availability.

# Sample Output from the REST API

```
HTTP / 1.1 200 OK
Server: nginx / 1.19.6
Date: Thu, 17 Dec 2020 05:36:48 GMT
Content-Type: text / html
Content-Length: 612
Last-Modified: Tue, 15 Dec 2020 13:59:38 GMT
Connection: keep-alive
ETag: "5fd8c14a-264"
Accept-Ranges: bytes

CONTAINER ID NAME CPU% MEM USAGE / LIMIT MEM% NET I / O BLOCK I / O PIDS
d33bb7b6e7a3 nginx 0.00% 2.488MiB / 983.3MiB 0.25% 1.81kB / 648B 9.5MB / 0B 2
```
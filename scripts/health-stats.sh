#!/bin/bash
while true
do
  curl -I localhost:80 >> /etc/resource.log
  docker stats nginx --no-stream >> /etc/resource.log
  sleep 10s
done
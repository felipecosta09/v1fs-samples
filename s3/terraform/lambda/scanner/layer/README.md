# Layer Configuration

This layer is used to provide the necessary dependencies for the scanner lambda function, currently the layer supports python 3.9 in a x86_64 architecture, but if you can generate your own layer to a desired python version/architecture.

To generate the layer, I've used a docker container with a specific python version and architecture, you cna build your docker container based on the [Dockerfile](Dockerfile) example:

```Dockerfile
FROM amd64/amazonlinux
WORKDIR /tmp 
RUN yum -y update
RUN yum install -y python-pip zip vim
RUN mkdir -p python 
RUN python3 -m pip install cloudone-vsapi --target ./python 
RUN cd .. 
RUN zip -r amaas_layer.zip .
```

Simply change the python version and architecture to your needs. At the end, extract the zip and replace with the [amaas_layer.zip](amaas_layer.zip) file, also remember to replace the architecture and python version in the layer resource and in the lambda function resource.
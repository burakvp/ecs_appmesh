FROM public.ecr.aws/appmesh/aws-appmesh-envoy:v1.18.4.0-prod
RUN yum update -y && \
    yum install -y jq curl unzip openssl less && \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rpm -e --nodeps unzip && \
    rm -rf awscliv2.zip ./aws/install && \
    yum clean all && \
    rm -rf /var/cache/yum

RUN mkdir /keys && chown 1337:1337 /keys 
COPY entrypoint.sh /bin/entrypoint.sh
RUN chmod +x /bin/entrypoint.sh
CMD ["/bin/entrypoint.sh"]
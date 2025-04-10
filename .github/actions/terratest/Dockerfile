FROM golang:1.24.1-alpine3.20

WORKDIR /

ARG TERRAFORM_VERSION=1.11.3
ARG KUBECTL_VERSION=1.32.3
ARG HELM_VERSION=3.17.0

RUN apk add --no-cache \
      bash \
      gcc \
      musl-dev \
      curl \
      git \
      jq \
      perl-utils \
      aws-cli && \
    git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile && ln -s ~/.tfenv/bin/* /usr/local/bin && \
    tfenv install $TERRAFORM_VERSION && \
    echo $TERRAFORM_VERSION > ~/.tfenv/version && \
    curl -sfSLO https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod u+x kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client=true && \
    curl -sfSLO https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/helm && \ 
    rm -rf linux-amd64 helm-v${HELM_VERSION}-linux-amd64.tar.gz && \
    helm version


COPY *.sh ./
ENTRYPOINT ["/entrypoint.sh"]

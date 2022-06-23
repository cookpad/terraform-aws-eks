FROM golang:1.17.3-alpine3.13

WORKDIR /

ARG TERRAFORM_VERSION=1.0.11
ARG KUBECTL_VERSION=1.22.11


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
    curl -sfSLO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    chmod u+x kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client=true

COPY *.sh ./
ENTRYPOINT ["/entrypoint.sh"]

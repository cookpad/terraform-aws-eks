FROM golang:1.17.3-alpine3.13

WORKDIR /

ARG TERRAFORM_VERSION=1.0.11
ARG KUBECTL_VERSION=1.24.2
ARG KUBECTL_SHA=f15fb430afd79f79ef7cf94a4e402cd212f02d8ec5a5e6a7ba9c3d5a2f954542


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
    echo "${KUBECTL_SHA}  kubectl" | sha256sum -c && \
    chmod u+x kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client=true

COPY *.sh ./
ENTRYPOINT ["/entrypoint.sh"]

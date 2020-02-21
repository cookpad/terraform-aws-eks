FROM alpine:3.11.2

ARG GOTESTSUM_VERSION=0.4.0
ARG TERRAFORM_VERSION=0.12.20
ARG KUBERNETES_VERSION=1.14.10

RUN apk add --no-cache \
      bash \
      curl \
      git \
      go \
      perl-utils \
      python3 && \
    pip3 install awscli && \
    git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile && ln -s ~/.tfenv/bin/* /usr/local/bin && \
    tfenv install $TERRAFORM_VERSION && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v$KUBERNETES_VERSION/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

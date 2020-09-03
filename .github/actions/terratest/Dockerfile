FROM alpine:3.12.0

ARG TERRAFORM_VERSION=0.12.24
ARG KUBERNETES_VERSION=1.15.11

RUN apk add --no-cache \
      bash \
      curl \
      git \
      go \
      jq \
      perl-utils \
      aws-cli && \
    git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile && ln -s ~/.tfenv/bin/* /usr/local/bin && \
    tfenv install $TERRAFORM_VERSION && \
    echo $TERRAFORM_VERSION > ~/.tfenv/version && \
    curl -LO https://storage.googleapis.com/kubernetes-release/release/v$KUBERNETES_VERSION/bin/linux/amd64/kubectl && \
    chmod +x ./kubectl && \
    mv ./kubectl /usr/local/bin/kubectl

COPY *.sh ./
ENTRYPOINT ["/entrypoint.sh"]

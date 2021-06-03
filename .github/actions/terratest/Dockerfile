FROM alpine:3.13.5

ARG TERRAFORM_VERSION=0.12.31
ARG KUBECTL_VERSION=1.20.5
ARG KUBECTL_SHA=7f9dbb80190945a5077dc5f4230202c22f68f9bd7f20c213c3cf5a74abf55e56

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
    curl -sfSLO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    echo "${KUBECTL_SHA}  kubectl" | sha256sum -c && \
    chmod u+x kubectl && \
    mv ./kubectl /usr/local/bin/kubectl && \
    kubectl version --client=true

COPY *.sh ./
ENTRYPOINT ["/entrypoint.sh"]

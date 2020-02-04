FROM alpine:3.11.2

ARG GOTESTSUM_VERSION=0.4.0
ARG TERRAFORM_VERSION=0.12.20

RUN apk add --no-cache \
      bash \
      curl \
      git \
      go \
      perl-utils \
      python3 && \
    pip3 install awscli --user && \
    git clone https://github.com/tfutils/tfenv.git ~/.tfenv && \
    echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bash_profile && ln -s ~/.tfenv/bin/* /usr/local/bin && \
    tfenv install $TERRAFORM_VERSION

COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

FROM alpine:3.12.1

WORKDIR /app
RUN apk add --no-cache go bash aws-cli jq
ADD . /app
RUN go build -o cleanup .
ENTRYPOINT ["/app/entrypoint.sh"]

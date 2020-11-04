FROM alpine:3.12.1

WORKDIR /app
RUN apk add --no-cache go
ADD . /app
RUN go build -o cleanup .
COPY *.sh ./
ENTRYPOINT ["/entrypoint.sh"]

FROM alpine:3.12.1

WORKDIR /app
RUN apk add --no-cache go bash
ADD . /app
RUN go build -o cleanup .
ENTRYPOINT ["/app/entrypoint.sh"]

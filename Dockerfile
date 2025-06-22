# Use the latest Alpine base image
FROM alpine:latest

# Install the Docker CLI
RUN apk update \
 && apk add --no-cache docker-cli \
 && rm -rf /var/cache/apk/*
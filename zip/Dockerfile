FROM alpine:latest

RUN apk add zip

# Create and assign runner user
RUN addgroup --system --gid 127 docker
RUN useradd --system -u 1001 -g 127 -ms /bin/bash runner
USER runner

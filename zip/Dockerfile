FROM alpine:latest

RUN apk add zip

# Create and assign runner user instead of root
RUN addgroup --system --gid 127 docker
RUN adduser --disabled-password --system --uid 1001 --ingroup "docker" --no-create-home --shell /bin/bash runner
USER runner

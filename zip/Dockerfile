FROM alpine:latest

RUN apk add zip

# Create and assign runner user
RUN addgroup --system --gid 127 docker
RUN adduser --disabled-password --system --uid 1001 --ingroup "docker" --no-create-home --shell /bin/bash runner
# RUN useradd --system -u 1001 -g 127 -ms /bin/bash runner
USER runner

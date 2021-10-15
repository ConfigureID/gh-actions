FROM stephenc/envsub AS binary

FROM alpine:latest

LABEL "maintainer"="Martin Moscovich <martinmoscovich@gmail.com>"

COPY --from=binary /bin/envsub /bin/
COPY --chown=root replace.sh /bin/
RUN chmod +x /bin/replace.sh

CMD /bin/replace.sh
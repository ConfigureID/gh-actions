FROM stephenc/envsub AS binary

FROM alpine:latest

LABEL "maintainer"="Martin Moscovich <martinmoscovich@gmail.com>"

COPY --from=binary /bin/envsub /bin/
ADD replace.sh /bin/

CMD replace.sh
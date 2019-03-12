FROM alpine

RUN apk add rsync

ENV PRESYNC=0
ENV TIME=30
ENV UID=0
ENV GID=0

COPY volsync /volsync
RUN chmod +x /volsync

VOLUME ["/vol/container", "/vol/host"]
WORKDIR /vol

CMD /volsync

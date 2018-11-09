# Requires Docker 17.09 or later (multi stage builds)

FROM oraclelinux:7-slim

ENV GOPATH=/tmp/go
ENV GOFILE=go1.10.1.linux-amd64.tar.gz

RUN yum update -y

RUN yum install -y \
  libcurl \
  rsync \
  gcc \
  gcc-c++ \
  bash \
  git \
  wget \
  which \
  && yum clean all

RUN wget https://dl.google.com/go/$GOFILE && \
 tar -xvf $GOFILE && \
 mv go $GOPATH && \
 rm $GOFILE

ENV PATH=$GOPATH"/bin:${PATH}"

RUN mkdir -p $GOPATH/src/github.com/github/orchestrator
WORKDIR $GOPATH/src/github.com/github/orchestrator
COPY . .
RUN bash build.sh -b
RUN rsync -av $(find /tmp/orchestrator-release -type d -name orchestrator -maxdepth 2)/ /
RUN rsync -av $(find /tmp/orchestrator-release -type d -name orchestrator-cli -maxdepth 2)/ /
RUN cp /usr/local/orchestrator/orchestrator-sample-sqlite.conf.json /etc/orchestrator.conf.json

FROM oraclelinux:7.5

EXPOSE 3000

COPY --from=0 /usr/local/orchestrator /usr/local/orchestrator
COPY --from=0 /etc/orchestrator.conf.json /etc/orchestrator.conf.json

WORKDIR /usr/local/orchestrator
ADD docker/entrypoint.sh /entrypoint.sh
CMD /entrypoint.sh

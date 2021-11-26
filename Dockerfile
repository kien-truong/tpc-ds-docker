FROM ubuntu:focal AS builder

WORKDIR /app

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y libarchive-tools build-essential curl && \
    apt-get clean && \
    apt-get autoremove

COPY files/tpc-ds-tool.zip /app/

RUN mkdir tpc-ds && \
    bsdtar xvf tpc-ds-tool.zip --strip-components=1 -C tpc-ds

RUN cd tpc-ds/tools && make

# Download Tini for PID 1
ARG TINI_VERSION=v0.19.0
RUN cd /app/ && \
    curl -O -L https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini && \
    chmod +x /app/tini

# Download GsUtils
ARG GCLOUD_SDK_VERSION=365.0.0
RUN curl -L https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-${GCLOUD_SDK_VERSION}-linux-x86_64.tar.gz \
    | tar -xzC /app

# Final image
FROM ubuntu:focal

WORKDIR /app

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y python3 && \
    apt-get clean && \
    apt-get autoremove

ENTRYPOINT ["/app/tini", "--"]
CMD ["/app/docker-entrypoint.sh"]

RUN groupadd -g 10000 tpc-ds && \
    useradd -u 10000 -g 10000 -d /app -r -s /sbin/nologin -c "TPD DS Service User" tpc-ds && \
    chown tpc-ds /app

COPY --from=builder /app/tini /app/
COPY --from=builder /app/google-cloud-sdk /app/google-cloud-sdk

ARG TPC_DS_HOME=/app/tpc-ds
COPY --from=builder /app/tpc-ds/tools/checksum ${TPC_DS_HOME}/
COPY --from=builder /app/tpc-ds/tools/distcomp ${TPC_DS_HOME}/
COPY --from=builder /app/tpc-ds/tools/dsdgen ${TPC_DS_HOME}/
COPY --from=builder /app/tpc-ds/tools/dsqgen ${TPC_DS_HOME}/
COPY --from=builder /app/tpc-ds/tools/mkheader ${TPC_DS_HOME}/
COPY --from=builder /app/tpc-ds/tools/tpcds.idx ${TPC_DS_HOME}/

COPY files/docker-entrypoint.sh /app/

RUN mkdir /app/output && \
    chown tpc-ds /app/output && \
    chmod +x /app/docker-entrypoint.sh

ENV SCALE_FACTOR=1
ENV OUTPUT_DIR=/app/output
ENV NUM_PARALLEL_JOB=1
ENV JOB_INDEX=1
ENV GCLOUD_SDK_HOME=/app/google-cloud-sdk
ENV TPC_DS_HOME=${TPC_DS_HOME}

USER tpc-ds
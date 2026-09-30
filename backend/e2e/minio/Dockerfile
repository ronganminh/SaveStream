FROM alpine:3.20

ARG TARGETARCH
ARG MINIO_RELEASE=RELEASE.2024-05-28T17-19-04Z

RUN apk add --no-cache ca-certificates curl \
    && curl -fsSL \
      "https://dl.min.io/server/minio/release/linux-${TARGETARCH}/archive/minio.${MINIO_RELEASE}" \
      -o /usr/local/bin/minio \
    && chmod +x /usr/local/bin/minio

EXPOSE 9000 9001
VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/minio"]
CMD ["server", "/data", "--console-address", ":9001"]

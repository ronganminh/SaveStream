FROM golang:1.23-alpine AS build

ARG MINIO_RELEASE=RELEASE.2024-05-28T17-19-04Z

RUN CGO_ENABLED=0 go install "github.com/minio/minio@${MINIO_RELEASE}"

FROM alpine:3.20

RUN apk add --no-cache ca-certificates curl
COPY --from=build /go/bin/minio /usr/local/bin/minio

EXPOSE 9000 9001
VOLUME ["/data"]

ENTRYPOINT ["/usr/local/bin/minio"]
CMD ["server", "/data", "--console-address", ":9001"]

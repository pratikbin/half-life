# syntax=docker/dockerfile:latest
ARG DISTROLESS_IMAGE=cgr.dev/chainguard/static:nonroot
ARG ALPINE=docker.io/library/alpine
# ARG AKASH=docker.io/library/ubuntu
ARG GO_VERSION=1.19

FROM --platform=$BUILDPLATFORM crazymax/goreleaser-xx:latest AS goreleaser-xx
FROM --platform=$BUILDPLATFORM golang:${GO_VERSION}-alpine AS base
ENV CGO_ENABLED=0
COPY --from=goreleaser-xx / /
RUN --mount=type=cache,target=/tmp/apkcache \
  apk add --cache-dir=/tmp/apkcache git make gcc g++
WORKDIR /src

FROM base AS build
ARG TARGETPLATFORM
RUN --mount=type=bind,source=.,rw \
  --mount=type=cache,target=/root/.cache \
  --mount=type=cache,target=/go/pkg/mod \
  goreleaser-xx --debug \
    --name="halflife" \
    --flags="-trimpath" \
    --ldflags="-s -w"

FROM --platform=$TARGETPLATFORM ${ALPINE} AS scratch-rootfs
RUN addgroup -S nonroot -g 65532 && \
	adduser -S nonroot -h /home/nonroot -G nonroot -u 65532
COPY --from=build /usr/local/bin/halflife /usr/local/bin/halflife
FROM scratch as alpine-rootfs
COPY --from=scratch-rootfs / /
ENTRYPOINT ["/usr/local/bin/halflife"]

FROM --platform=$TARGETPLATFORM alpine-rootfs AS prod

FROM --platform=$TARGETPLATFORM alpine-rootfs AS nonroot
USER nonroot:nonroot

FROM --platform=$TARGETPLATFORM ${DISTROLESS_IMAGE} AS distroless
COPY --from=build /usr/local/bin/halflife /usr/local/bin/halflife
ENTRYPOINT ["/usr/local/bin/halflife"]

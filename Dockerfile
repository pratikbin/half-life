# syntax=docker/dockerfile:latest
ARG distroless_image=cgr.dev/chainguard/static
ARG prod_image=alpine
# ARG AKASH_IMAGE=docker.io/library/ubuntu
ARG go_image=golang:1.19

FROM --platform=$BUILDPLATFORM crazymax/goreleaser-xx:latest AS goreleaser-xx
FROM --platform=$BUILDPLATFORM ${go_image} AS base
ENV CGO_ENABLED=0
COPY --from=goreleaser-xx / /
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

FROM --platform=$TARGETPLATFORM ${prod_image} AS scratch-rootfs
RUN addgroup -S nonroot -g 65532 && \
  adduser -S nonroot -h /home/nonroot -G nonroot -u 65532
COPY --from=build /usr/local/bin/halflife /usr/local/bin/halflife
FROM scratch as rootfs
COPY --from=scratch-rootfs / /
ENTRYPOINT ["/usr/local/bin/halflife"]

FROM --platform=$TARGETPLATFORM rootfs AS prod

FROM --platform=$TARGETPLATFORM rootfs AS nonroot
USER nonroot:nonroot

FROM --platform=$TARGETPLATFORM ${distroless_image} AS distroless
COPY --from=build /usr/local/bin/halflife /usr/local/bin/halflife
ENTRYPOINT ["/usr/local/bin/halflife"]

ARG CLI_IMAGE
ARG UPSTREAM_REPO
FROM ${CLI_IMAGE:-builder} as builder

FROM ${UPSTREAM_REPO:-uselagoon}/php-7.4-fpm

COPY --from=builder /app /app

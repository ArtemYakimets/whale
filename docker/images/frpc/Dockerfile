ARG FRP_VERSION=0.58.1
FROM alpine:3.19 AS downloader
ARG FRP_VERSION
WORKDIR /tmp
RUN apk add --no-cache curl tar \
    && curl -fsSL "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_amd64.tar.gz" -o frp.tar.gz \
    && tar -xzf frp.tar.gz

FROM alpine:3.19
ARG FRP_VERSION
RUN apk add --no-cache gettext
COPY --from=downloader /tmp/frp_${FRP_VERSION}_linux_amd64/frpc /usr/local/bin/frpc
COPY docker/images/frpc/entrypoint.sh /entrypoint.sh
COPY config/frp/frpc.ini /etc/frp/frpc.ini
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

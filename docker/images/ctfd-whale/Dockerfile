FROM alpine/git:2.45.2 AS whale_plugin
WORKDIR /src
RUN git clone --depth=1 https://github.com/frankli0324/CTFd-Whale.git .

FROM ghcr.io/ctfd/ctfd:3.5.3
USER root
RUN printf 'deb http://archive.debian.org/debian buster main contrib non-free\n' > /etc/apt/sources.list \
    && printf 'deb http://archive.debian.org/debian buster-updates main contrib non-free\n' >> /etc/apt/sources.list \
    && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until \
    && apt-get update \
    && apt-get install -y --no-install-recommends gettext-base curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=whale_plugin /src /opt/CTFd/plugins/ctfd-whale
RUN pip install --no-cache-dir -r /opt/CTFd/plugins/ctfd-whale/requirements.txt
COPY docker/images/ctfd-whale/entrypoint.sh /opt/ctfd-whale-entrypoint.sh
RUN chmod +x /opt/ctfd-whale-entrypoint.sh
USER ctfd
ENTRYPOINT ["/opt/ctfd-whale-entrypoint.sh"]
CMD ["gunicorn", "-k", "gevent", "-w", "4", "-b", "0.0.0.0:8000", "CTFd:create_app()"]

FROM python:3.9-slim
WORKDIR /data
RUN apt update \
        && apt install -y bash curl git jq make xxd \
        && apt clean \
        && rm -rf /var/lib/apt/lists/*
RUN curl -sSL 'https://go.dev/dl/go1.20.14.linux-amd64.tar.gz' | tar -xz -C /usr/local
ENV PATH="$PATH:/usr/local/go/bin"
RUN curl 'https://download.docker.com/linux/debian/dists/bookworm/pool/stable/amd64/docker-ce-cli_23.0.6-1~debian.12~bookworm_amd64.deb' -o /tmp/docker-ce-cli.deb \
        && curl 'https://download.docker.com/linux/debian/dists/bookworm/pool/stable/amd64/docker-buildx-plugin_0.11.2-1~debian.12~bookworm_amd64.deb' -o /tmp/docker-buildx-plugin.deb \
        && dpkg -i /tmp/docker-ce-cli.deb /tmp/docker-buildx-plugin.deb \
        && rm -f /tmp/docker-ce-cli.deb /tmp/docker-buildx-plugin.deb
COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/

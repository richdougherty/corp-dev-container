ARG UBUNTU_IMAGE_TAG="plucky-20250714"

# Build a minimal Ubuntu to let us download and install other packages
FROM ubuntu:${UBUNTU_IMAGE_TAG} AS ubuntu-min-packages
RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update && \
  apt --no-install-recommends install -y \
    ca-certificates \
    gpg \
    # Needed for vault install
    libcap2-bin

# https://developer.hashicorp.com/vault/install
# https://mise.jdx.dev/installing-mise.html#apt
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-using-native-package-management
FROM ubuntu-min-packages AS apt-extra-repositories-config
ADD --checksum=sha256:cafb01beac341bf2a9ba89793e6dd2468110291adfbb6c62ed11a0cde6c09029 https://apt.releases.hashicorp.com/gpg /tmp/hashicorp.gpg.asc
ADD --checksum=sha256:91c72340c5cc84ae2ba98c1070083feacf789b0a4a3d34b2416147769e475d96 https://mise.jdx.dev/gpg-key.pub /tmp/mise.gpg.asc
ADD --checksum=sha256:7627818cf7bae52f9008c93e8b1f961f53dea11d40891778de216fb1b43be54d https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key /tmp/kubernetes.gpg.asc
RUN \
  mkdir -p /apt-config/keyrings && \
  gpg --dearmor -o /apt-config/keyrings/hashicorp.gpg /tmp/hashicorp.gpg.asc && \
  gpg --dearmor -o /apt-config/keyrings/mise.gpg /tmp/mise.gpg.asc && \
  gpg --dearmor -o /apt-config/keyrings/kubernetes.gpg /tmp/kubernetes.gpg.asc && \
  mkdir -p /apt-config/sources.list.d && \
  DEBIAN_ARCH="$(dpkg --print-architecture)" && \
  UBUNTU_CODENAME="$(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release)" && \
  echo "deb [arch=$DEBIAN_ARCH signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $UBUNTU_CODENAME main" > /apt-config/sources.list.d/hashicorp.list && \
  echo "deb [arch=$DEBIAN_ARCH signed-by=/etc/apt/keyrings/mise.gpg] https://mise.jdx.dev/deb stable main" > /apt-config/sources.list.d/mise.list && \
  echo "deb [arch=$DEBIAN_ARCH signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" > /apt-config/sources.list.d/kubernetes.list

FROM ubuntu-min-packages AS apt-extra-repositories
COPY --from=apt-extra-repositories-config --link /apt-config/ /etc/apt/

FROM apt-extra-repositories AS apt-install
RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update && \
  apt --no-install-recommends install -y \
    bzip2 \
    curl \
    git \
    kubectl \
    less \
    mise \
    netcat-traditional \
    psmisc \
    sudo \
    unzip \
    vault \
    wget \
    xz-utils \
    zip && \
  setcap -r /usr/bin/vault && \
  echo "ALL ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

FROM apt-extra-repositories AS mise
RUN \
  --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  apt update && \
  apt --no-install-recommends install -y \
    mise && \
  export MISE_DATA_DIR=/usr/local/share/mise/ ; \
  mkdir /usr/local/share/mise && \
  # All all to read/write, since this is just a dev container
  chmod 777 /usr/local/share/mise

FROM mise AS mise-install-python
RUN \
  export MISE_DATA_DIR=/usr/local/share/mise/ ; \
  mise install python@3.13.5

# FROM apt-install AS mise-install-java
# RUN MISE_DATA_DIR=/usr/local/share/mise ; mise install java@temurin-21.0.8+9.0.LTS

FROM mise AS mise-install-node
RUN \
  export MISE_DATA_DIR=/usr/local/share/mise/ ; \
  # Run install twice because first install fails with gpg-agent error. (TODO: Investigate why.)
  mise install node@24.4.1 ; mise install node@24.4.1

FROM apt-install AS assemble
COPY --from=mise-install-python --link /usr/local/share/mise/ /usr/local/share/mise/
# COPY --chown=ubuntu:ubuntu --from=mise-install-java --link /home/ubuntu/.local/share/mise/ /home/ubuntu/.local/share/mise/
COPY --from=mise-install-node --link /usr/local/share/mise/ /usr/local/share/mise/
COPY --from=amazon/aws-cli:2.27.55 --link /usr/local/aws-cli/ /usr/local/aws-cli/
RUN \
  ln -s /usr/local/aws-cli/v2/current/bin/* /usr/local/bin/

COPY ./files/ /opt/corp-dev-container/
ENTRYPOINT [ "/opt/corp-dev-container/entrypoint" ]
CMD [ "/bin/bash" ]
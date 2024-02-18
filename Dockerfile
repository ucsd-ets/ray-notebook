
FROM rayproject/ray-ml:latest-gpu

USER root

ENV PATH=/home/ray/anaconda3/bin:/usr/local/nvidia/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

#############################
# Standard datahub additions
# (see # https://raw.githubusercontent.com/ucsd-ets/datahub-docker-stack/main/images/datascience-notebook/Dockerfile )

ENV DEBIAN_FRONTEND noninteractive
ENV DEBCONF_NOWARNINGS="yes"

RUN apt-get update -y && \
    apt-get -qq install -y --no-install-recommends \
    git \
    curl \
    rsync \
    unzip \
    less \
    nano \
    vim \
    cmake \
    tmux \
    screen \
    gnupg \
    htop \
    netcat \
    wget \
    openssh-client \
    openssh-server \
    p7zip \
    apt-utils \
    jq \
    build-essential \
    p7zip-full && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    chmod g-s /usr/bin/screen && \
    chmod 1777 /var/run/screen

#############################
# download and install kubectl
ENV KUBECTL_VERSION=v1.25.0
WORKDIR /opt 
RUN curl -LO https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

#############################
# Install jupyter components
RUN pip3 install notebook==6.4.0 jupyter-server-proxy jupyterhub==1.5.0 jupyter databricks==0.2 koalas==1.8.2 pandas nbgrader==0.8.1 scikit-learn -v

RUN jupyter nbextension install --symlink --sys-prefix --py nbgrader && \
  jupyter nbextension enable --sys-prefix --py nbgrader && \
  jupyter serverextension enable --sys-prefix --py nbgrader && \
  jupyter labextension enable --level=system nbgrader && \
  jupyter server extension enable --system --py nbgrader

#############################
# Jupyter project standard startup scripts
COPY start-notebook.sh /usr/local/bin
COPY start.sh /usr/local/bin
COPY start-singleuser.sh /usr/local/bin
RUN chmod 777 /usr/local/bin/start-notebook.sh /usr/local/bin/start.sh /usr/local/bin/start-singleuser.sh
RUN mkdir -p -m 750 /usr/local/bin/before-notebook.d

#############################
# Finally, our local support scripts 
ENV STOP_CLUSTER_SCRIPT_PATH=/opt/ray-support/stop-cluster.sh
ENV START_CLUSTER_SCRIPT_PATH=/opt/ray-support/start-cluster.sh
ENV SHELL=/bin/bash

RUN mkdir -p /opt/ray-support
COPY jupyter_config.py start-workers.sh start-cluster.sh stop-cluster.sh /opt/ray-support
RUN chmod 0755 /opt/ray-support/*.sh
RUN mkdir -p /usr/local/etc/jupyter && cat /opt/ray-support/jupyter_config.py >> /usr/local/etc/jupyter/jupyter_config.py

# install bazel
RUN apt install apt-transport-https curl gnupg -y && \
    curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg && \
    mv bazel-archive-keyring.gpg /usr/share/keyrings && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list
RUN apt update && apt install bazel-3.2.0
# downgrade protobuf and numpy for transformers and pygloo
RUN pip3 install protobuf==3.20.0 numpy==1.20.0
# install pygloo
RUN git clone https://github.com/ray-project/pygloo.git
RUN alias bazel="bazel-3.2.0" && cd pygloo && python setup.py install && cd ..

USER 1000


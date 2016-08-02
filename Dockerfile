FROM debian:jessie

## Clean documentation in FROM image
RUN find /usr/share/doc -depth \( -type f -o -type l \) ! -name copyright | xargs rm || true
## Clean doc directories that are empty or only contain empty directories
RUN while [ -n "$(find /usr/share/doc -depth -type d -empty -print -exec rmdir {} +)" ]; do :; done
RUN rm -rf                              \
        /usr/share/man/*                \
        /usr/share/groff/*              \
        /usr/share/info/*               \
        /usr/share/lintian/*            \
        /usr/share/linda/*              \
        /var/cache/man/*                \
        /usr/share/locale/*

## Set the apt source
COPY sources.list /etc/apt/sources.list
COPY dpkg_01_drop /etc/dpkg/dpkg.cfg.d/01_drop
RUN apt-get clean && apt-get update

## Pre-install the fundamental packages
RUN apt-get -y install                  \
    rsyslog                             \
    vim-tiny                            \
    perl                                \

COPY rsyslog.conf /etc/rsyslog.conf

RUN apt-get -y purge                    \
    exim4                               \
    exim4-base                          \
    exim4-config                        \
    exim4-daemon-light

## Python installations (based on Docker Hub "Slim Python" builds.
RUN apt-get purge -y python.*
ENV LANG C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates \
		libssl1.0.0

ENV PY2_GPG_KEY C01E1CAD5EA2C4F0B8E3571504C367C218ADD4FF
ENV PY3_GPG_KEY 97FC712E4C024BBEA48A61ED3A5CA953F73C700D

# set Python/pip versions here
ENV PYTHON2_VERSION 2.7.12
ENV PYTHON_PIP2_VERSION 8.1.2
ENV PYTHON3_VERSION 3.5.2
ENV PYTHON_PIP3_VERSION 8.1.2

# Install Python2 (based on https://hub.docker.com/_/python/)
RUN set -ex \
	&& buildDeps=' \
		curl \
		gcc \
		libc6-dev \
		libssl-dev \
		make \
	' \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends \
	&& curl -fSL "https://www.python.org/ftp/python/${PYTHON2_VERSION%%[a-z]*}/Python-$PYTHON2_VERSION.tar.xz" -o python.tar.xz \
	&& curl -fSL "https://www.python.org/ftp/python/${PYTHON2_VERSION%%[a-z]*}/Python-$PYTHON2_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$PY2_GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -r "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	&& cd /usr/src/python \
	&& ./configure \
		--enable-shared \
		--enable-unicode=ucs4 \
		--without-doc-strings \
		--prefix=/usr \
		--without-pymalloc \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& curl -fSL 'https://bootstrap.pypa.io/get-pip.py' | python2 \
	&& pip install --no-cache-dir --upgrade pip==$PYTHON_PIP2_VERSION \
	&& [ "$(pip list | awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP2_VERSION" ] \
	&& find /usr/lib -depth \
		\( \
		    \( -type d -a -name test -o -name tests \) \
		    -o \
		    \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		\) -exec rm -rf '{}' + \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& rm -rf /usr/src/python ~/.cache

# Install Python3 (based on https://hub.docker.com/_/python/)
RUN set -ex \
	&& buildDeps=' \
		curl \
		gcc \
		libc6-dev \
		libssl-dev \
		make \
	' \
	&& apt-get update && apt-get install -y $buildDeps --no-install-recommends  \
	&& curl -fSL "https://www.python.org/ftp/python/${PYTHON3_VERSION%%[a-z]*}/Python-$PYTHON3_VERSION.tar.xz" -o python.tar.xz \
	&& curl -fSL "https://www.python.org/ftp/python/${PYTHON3_VERSION%%[a-z]*}/Python-$PYTHON3_VERSION.tar.xz.asc" -o python.tar.xz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$PY3_GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -r "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	&& cd /usr/src/python \
	&& ./configure \
		--enable-loadable-sqlite-extensions \
		--enable-shared \
		--without-doc-strings \
		--prefix=/usr \
		--without-pymalloc \
	&& make -j$(nproc) \
	&& make install \
	&& ldconfig \
	&& pip3 install --no-cache-dir --upgrade pip==$PYTHON_PIP3_VERSION \
	&& [ "$(pip3 list | awk -F '[ ()]+' '$1 == "pip" { print $2; exit }')" = "$PYTHON_PIP3_VERSION" ] \
	&& find /usr/lib -depth \
		\( \
		    \( -type d -a -name test -o -name tests \) \
		    -o \
		    \( -type f -a -name '*.pyc' -o -name '*.pyo' \) \
		\) -exec rm -rf '{}' + \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& rm -rf /usr/src/python ~/.cache

## Clean up
RUN apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y
## Note: NO removing /var/lib/apt/lists/*, shared by all derived images
## TODO: if it is possible to squash derived images, remove it here
RUN rm -rf /tmp/*

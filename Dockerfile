# Builds an Alpine linux distribution with Python 3.3 and then installs the glTF API
# docker build --tag headjack/gltf:0.0.2 .

FROM alpine:3.4
MAINTAINER Nick Kraakman

# ensure local python is preferred over distribution python
ENV PATH /usr/local/bin:$PATH

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG C.UTF-8

# install ca-certificates so that HTTPS works consistently
# the other runtime dependencies for Python are installed later
RUN apk add --no-cache ca-certificates

ENV GPG_KEY 0D96DF4D4110E5C43FBFB17F2D347EA6AA65421D
ENV PYTHON_VERSION 3.3.7

RUN set -ex \
	&& apk add --no-cache --virtual .fetch-deps \
		gnupg \
		openssl \
		tar \
		xz \
	\
	&& wget -O python.tar.xz "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz" \
	&& wget -O python.tar.xz.asc "https://www.python.org/ftp/python/${PYTHON_VERSION%%[a-z]*}/Python-$PYTHON_VERSION.tar.xz.asc" \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$GPG_KEY" \
	&& gpg --batch --verify python.tar.xz.asc python.tar.xz \
	&& rm -rf "$GNUPGHOME" python.tar.xz.asc \
	&& mkdir -p /usr/src/python \
	&& tar -xJC /usr/src/python --strip-components=1 -f python.tar.xz \
	&& rm python.tar.xz \
	\
	&& apk add --no-cache --virtual .build-deps  \
		bzip2-dev \
		coreutils \
		dpkg-dev dpkg \
		expat-dev \
		gcc \
		gdbm-dev \
		libc-dev \
		libffi-dev \
		linux-headers \
		make \
		ncurses-dev \
		openssl \
		openssl-dev \
		pax-utils \
		readline-dev \
		sqlite-dev \
		tcl-dev \
		tk \
		tk-dev \
		xz-dev \
		zlib-dev \
# add build deps before removing fetch deps in case there's overlap
	&& apk del .fetch-deps \
	\
	&& cd /usr/src/python \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--enable-loadable-sqlite-extensions \
		--enable-shared \
		--with-system-expat \
		--with-system-ffi \
		--without-ensurepip \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --virtual .python-rundeps $runDeps \
	&& apk del .build-deps \
	\
	&& find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' + \
	&& rm -rf /usr/src/python

# make some useful symlinks that are expected to exist
RUN cd /usr/local/bin \
	&& ln -s idle3 idle \
	&& ln -s pydoc3 pydoc \
	&& ln -s python3 python \
	&& ln -s python3-config python-config

# if this is called "PIP_VERSION", pip explodes with "ValueError: invalid truth value '<VERSION>'"
ENV PYTHON_PIP_VERSION 9.0.1

RUN set -ex; \
	\
	apk add --no-cache --virtual .fetch-deps openssl; \
	\
	wget -O get-pip.py 'https://bootstrap.pypa.io/get-pip.py'; \
	\
	apk del .fetch-deps; \
	\
	python get-pip.py \
		--disable-pip-version-check \
		--no-cache-dir \
		"pip==$PYTHON_PIP_VERSION" \
	; \
	pip --version; \
	\
	find /usr/local -depth \
		\( \
			\( -type d -a \( -name test -o -name tests \) \) \
			-o \
			\( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
		\) -exec rm -rf '{}' +; \
	rm -f get-pip.py

# copy all project files
COPY . /var/www
EXPOSE 5018

# install FBX SDK, its Python bindings, and all Python packages in requirements.txt
RUN wget http://download.autodesk.com/us/fbx/2018/2018.1.1/fbx20181_1_fbxsdk_linux.tar.gz \
	&& tar xzvf fbx20181_1_fbxsdk_linux.tar.gz --directory /tmp/ \
	&& printf 'y\nyes\nno\n' | ./tmp/fbx20181_1_fbxsdk_linux \
	&& rm -f fbx20181_1_fbxsdk_linux.tar.gz \
	&& rm -f ./tmp/fbx20181_1_fbxsdk_linux \
	&& wget http://download.autodesk.com/us/fbx/2018/2018.1.1/fbx20181_1_fbxpythonsdk_linux.tar.gz \
	&& tar xzvf fbx20181_1_fbxpythonsdk_linux.tar.gz --directory /tmp/ \
	&& printf 'y\nyes\nno\n' | ./tmp/fbx20181_1_fbxpythonsdk_linux \
	&& mv -v /lib/Python33_x64/* /usr/local/lib/python3.3/site-packages \
	&& rm -f ./tmp/fbx20181_1_fbxpythonsdk_linux.tar.gz \
	&& pip install -r /var/www/requirements.txt \
	&& cd /var/www/app \
	&& python database.py

# start API
CMD ["python", "/var/www/app/api.py"]

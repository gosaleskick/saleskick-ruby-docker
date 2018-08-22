FROM debian:jessie

RUN apt-get update\
    && apt-get install -y --no-install-recommends \
    bzip2 \
    ca-certificates \
    curl \
    libffi-dev \
    libgdbm3 \
    libssl-dev \
    libyaml-dev \
    procps \
    zlib1g-dev \
    libjemalloc-dev \
    htop \
    vim \
    && rm -rf /var/lib/apt/lists/*

# do not install gems docs
RUN mkdir -p /usr/local/etc \
    && { \
          echo 'install: --no-document'; \
          echo 'update: --no-document'; \
    } >> /usr/local/etc/gemrc


ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.4
ENV RUBY_DOWNLOAD_SHA256 1d0034071d675193ca769f64c91827e5f54cb3a7962316a41d5217c7bc6949f0
ENV RUBYGEMS_VERSION 2.7.7
ENV BUNDLER_VERSION 1.16.4

RUN set -ex \
	\
	&& buildDeps=' \
		autoconf \
		bison \
		dpkg-dev \
		gcc \
		libbz2-dev \
		libgdbm-dev \
		libglib2.0-dev \
		libncurses-dev \
		libreadline-dev \
		libxml2-dev \
		libxslt-dev \
		make \
		ruby \
		wget \
		xz-utils \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
  && { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
		--with-jemalloc \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& dpkg-query --show --showformat '${package}\n' \
		| grep -P '^libreadline\d+$' \
		| xargs apt-mark manual \
	&& apt-get purge -y --auto-remove $buildDeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	\
	&& gem update --system "$RUBYGEMS_VERSION" \
	&& gem install bundler --version "$BUNDLER_VERSION" --force \
	&& rm -r /root/.gem/

RUN ruby -r rbconfig -e "RbConfig::CONFIG['LIBS'].include?('jemalloc') ? puts('Ruby is compiled with jemalloc') : warn('JEMALLOC IS MISSING FROM RUBY')"

ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

CMD [ "irb" ]

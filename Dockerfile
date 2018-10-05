# Image recompiles OpenSSl in FIPS compiliant mode and uses it to rebuild Node 8.12.0 with a FIPS compliant crypto module

FROM alpine:3.8 

ARG OPENSSL_FIPS_VER=2.0.16
ARG OPENSSL_FIPS_HASH=a3cd13d0521d22dd939063d3b4a0d4ce24494374b91408a05bdaca8b681c63d4
ARG OPENSSL_FIPS_PGP_FINGERPRINT=D3577507FA40E9E2


RUN  apk update \
  &&  cd /root  \
  &&  apk upgrade  \
  &&  apk add --update wget gcc gzip tar libc-dev ca-certificates perl make coreutils gpg2 linux-headers zlib-dev  \
  &&  wget --quiet https://www.openssl.org/source/openssl-fips-$OPENSSL_FIPS_VER.tar.gz  \
  &&  wget --quiet https://www.openssl.org/source/openssl-fips-$OPENSSL_FIPS_VER.tar.gz.asc  \
  &&  gpg --keyserver hkp://pgp.mit.edu --recv $OPENSSL_FIPS_PGP_FINGERPRINT \
  &&  gpg --verify openssl-fips-$OPENSSL_FIPS_VER.tar.gz.asc openssl-fips-$OPENSSL_FIPS_VER.tar.gz \
  &&  echo "$OPENSSL_FIPS_HASH openssl-fips-$OPENSSL_FIPS_VER.tar.gz" | sha256sum -c - | grep OK  \
  &&  tar -xzf openssl-fips-$OPENSSL_FIPS_VER.tar.gz  \
  &&  pwd \
  &&  echo "openssl-fips-$OPENSSL_FIPS_VER" \
  &&  cd openssl-fips-$OPENSSL_FIPS_VER \
  &&  pwd \
  &&  ./config \
  &&  make  \
  &&  make install \ 
  &&  cd .. \
  &&  ls /usr/local/ssl/fips-2.0/lib | grep fipscanister.o

#------------- BUILD NODE -----

ARG NODE_VERSION=8.12.0

RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        binutils-gold \
        g++ \
        libgcc \
        python \
    &&  wget --quiet https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.gz \
    &&  wget --quiet https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt \
    && grep " node-v$NODE_VERSION.tar.gz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xzf "node-v$NODE_VERSION.tar.gz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure --openssl-fips=/usr/local/ssl/fips-2.0 \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && apk del .build-deps \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.gz" SHASUMS256.txt
    
RUN node -p "process.versions.openssl" | grep fips

ENV YARN_VERSION 1.9.4

RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && apk del .build-deps-yarn

CMD [ "node" ]


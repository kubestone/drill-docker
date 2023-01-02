FROM rust:1.66.0-slim-bullseye as cargo-build

ARG DRILL_VERSION=0.8.1
ARG OPENSSL_VERSION=1.1.1s

RUN apt-get update && \
    apt-get install -y curl musl-tools make pkg-config linux-headers-amd64 && \
    rustup target add x86_64-unknown-linux-musl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Build OpenSSL with musl-gcc: the apt provided ssl does not work with drill & hyper
ENV MUSL=/musl
ENV CC=musl-gcc
ENV LD_LIBRARY_PATH=/musl

RUN cd /src && \
    ln -s /usr/include/x86_64-linux-gnu/asm /usr/include/x86_64-linux-musl/asm && \
    ln -s /usr/include/asm-generic /usr/include/x86_64-linux-musl/asm-generic && \
    ln -s /usr/include/linux /usr/include/x86_64-linux-musl/linux && \
    curl -L -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    CC="musl-gcc -fPIE -pie -static -idirafter /usr/include/ -idirafter /usr/include/x86_64-linux-gnu/" ./Configure no-zlib no-shared -fPIC --prefix=${MUSL} --openssldir=${MUSL}/ssl linux-x86_64 && \
    C_INCLUDE_PATH=${MUSL}/include make depend && \
    make && \
    make install
ENV OPENSSL_DIR=${MUSL}

RUN cd /src && \
    curl -L -O https://github.com/fcsonline/drill/archive/${DRILL_VERSION}.tar.gz && \
    tar xzf ${DRILL_VERSION}.tar.gz && \
    ln -s drill-${DRILL_VERSION} drill && \
    cd drill && \
    RUSTFLAGS=-Clinker=musl-gcc cargo build --release --target=x86_64-unknown-linux-musl


FROM alpine:20190707

COPY --from=cargo-build /src/drill/target/x86_64-unknown-linux-musl/release/drill /usr/local/bin/drill

ENTRYPOINT ["/usr/local/bin/drill"]

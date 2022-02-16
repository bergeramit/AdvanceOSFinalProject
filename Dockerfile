FROM ubuntu:18.04
LABEL maintainer="Amit Berger"

RUN set -ex; \
	apt-get update -y; \
	DEBIAN_FRONTEND=noninteractive apt install -y \
	bison \
	build-essential \
	cmake \
	flex \
	git \
	libedit-dev \
	libllvm6.0 \
	llvm-6.0-dev \
	libclang-6.0-dev \
	python \
	zlib1g-dev \
	libelf-dev \
	libfl-dev \
	python3-distutils;


EXPOSE 22 80
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]

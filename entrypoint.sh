#!/bin/bash
set -e
rm -rf bcc
git clone https://github.com/iovisor/bcc.git
cd bcc && git checkout 552551946a27a8d27086d289a5925b7e75a53ed8
mkdir build; cd build
cmake ..
make
make install
cmake -DPYTHON_CMD=python3 .. # build python3 binding
pushd src/python/
make
make install
popd
mount -t debugfs none /sys/kernel/debug/
cd /usr/share/proto2ebpf
exec "$@"

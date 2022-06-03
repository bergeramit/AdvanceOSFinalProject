
# Final Project Progress Journal

In order to get the bcc docker running (from: https://github.com/zlim/bcc-docker) I needed to:

1. install a clean version of Ubuntu 18.04 on my Windows 10 Virtual Box
   1. did not work out-of-the-box with:
      1. ubuntu 20
      2. WLS2
      3. Arch
2. install docker with:
```
sudo apt install docker.io
```
3. install linux headers with:
```
sudo apt install linux-headers-`uname -r`
```
4. run the docker command with:
```
docker run -it --rm \
  --privileged \
  -v /lib/modules:/lib/modules:ro \
  -v /usr/src:/usr/src:ro \
  -v /etc/localtime:/etc/localtime:ro \
  --workdir /usr/share/bcc/tools \
  zlim/bcc
```
5. can compile my own with:
```
cd bcc-docker
mv Dockerfile.bionic Dockerfile
sudo docker image build -t my_bcc_docker .
sudo docker image ls
docker run -it --rm --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -v /etc/localtime:/etc/localtime:ro --workdir /usr/share/bcc/tools my_bcc_docker
```
6. to run an example use:
On the first terminal:
```
cd /usr/share/bcc/examples/
python hello_world.py
```
Next open another terminal in the host and run:
```
sudo docker container exec -it <CONTAINER ID> /bin/bash
```
Should print hello world with function trace in the first terminal

# Trying to make the examples work:
compiling bcc from scratch:
(following: https://github.com/iovisor/bcc/blob/master/INSTALL.md#ubuntu---source)
```
sudo apt-get -y install bison build-essential cmake flex git libedit-dev \
  libllvm6.0 llvm-6.0-dev libclang-6.0-dev python zlib1g-dev libelf-dev libfl-dev python3-distutils
git clone https://github.com/iovisor/bcc.git
mkdir bcc/build; cd bcc/build
cmake ..
make
sudo make install
cmake -DPYTHON_CMD=python3 .. # build python3 binding
pushd src/python/
make
sudo make install
popd
```
Success! (shows up in the Dockerfile)

We now have on our machine the compiled bcc with working examples like:
```
amit@amit-VirtualBox:~/bcc/examples/networking/http_filter$ sudo python3 http-parse-simple.py -i lo
```
And on another terminal we can:
```
python3 -m http.server
```
And another terminal to run:
```
curl 0.0.0.0:8000
```

# Building Docker with our bcc build

After eternity, build with:
```
sudo docker image build -t my_bcc_docker .
```
Dockerfile contains the latest build config
Run docker with:
```
sudo docker run -it --rm --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -v /etc/localtime:/etc/localtime:ro -v /home/amit/final_project/proto2ebpf:/usr/share/proto2ebpf --network="host" --workdir /usr/share/bcc/examples my_bcc_docker
```
where the entry is: entrypoint.sh

## Docker compose

*probably uneeded compose because we use host as network to make our tests on loopback*

Install with:
```
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```
Run with:
```
docker-compose up
```

# Testing my repo

I started to write the proto2ebpf repo and I placed it here:
```
https://github.com/bergeramit/proto2ebpf.git
```

To run this simply clone the proto2ebpf to this folder and run the docker build and docker run command (I have included a sample of this repo here)

Now we will run this with the docker run with host network (since we want to test the ebpf works in our localhost):

```
# Build with:
sudo docker image build -t my_bcc_docker .

# Run with
sudo docker run -it --rm --privileged -v /lib/modules:/lib/modules:ro -v /usr/src:/usr/src:ro -v /etc/localtime:/etc/localtime:ro -v /home/amit/AdvanceOSFinalProject/proto2ebpf:/usr/share/proto2ebpf --network="host" --workdir /usr/share/proto2ebpf my_bcc_docker
```

# Final Build

Server with protobuf filter
```
sudo docker container exec -it <CONTAINER_ID> /bin/bash
python3.6 proto2ebpf.py --env=server_with_filter
```

Server without protobuf filter:
```
sudo docker container exec -it <CONTAINER_ID> /bin/bash
python3.6 proto2ebpf.py --env=server_without_filter
```

TO run a client against those servers
```
sudo docker container exec -it <CONTAINER_ID> /bin/bash
python3.6 proto2ebpf.py --env=client
```

# AdvanceOSFinalProject

This project is aimed to determine and prove that eBPF code that will enforce rules regarding protobufs will be faster than writing those restrictive rulse in the containers. This will help future applications to scale with the use of the protobuf-to-ebpf library.

## Project has 3 parts

1. The litrature in the subject (on "What was already available ?")
2. This repo which contains:
   1. The environment I built for the tests 
   2. The results of the expirements and how I tested the assumption I begun with
   3. Explanation of the results
   4. The retrospective
   5. Future work
4. The https://github.com/bergeramit/proto2ebpf.git repo which has the implementation of translating simple protobuf rules into eBPFs

# What was already available ?

## Capabilities ( not-in-linux-context :slightly_smiling_face: ) of eBPF
   1. 11 64-bit registers
   2. 9 general purpose
   3. 1 PC
   4. 1 512 byte stack register
2. supports 32 bit architectures as well
3. can support up to 8 byte load/store inst
4. Function calls can have at most 5 parameters
5. every pointer must be to a stack (no free address pointers)
6. Can access maps and contexts - can be shared
7. includes around 100 inst (mainly mov, store, load, calculations and conditional jumps)
8. no loops
9. must have at most 4096 instructions in each eBPF VM
10. Compiler
   1. compiles into bytecode so can be ran on a 32bit systems as well (cross platform)
   2. JIT in kernel

## Capabilities ( not-in-linux-context :slightly_smiling_face: ) of Protobuf

1. language-neutral, platform-neutral, extensible mechanism for serializing structured data
2. encodes into bytes
3. out-of-the-box support for python and GO (potentially one of the desired languages for this project)
4. very well documented encoding scheme (makes it easier to write a compiler to eBPF from, https://developers.google.com/protocol-buffers/docs/encoding#packed )
   1. based on bit operations - can be easily done with the eBPF instruction set
   2. key value pairs all the way down
   3. types of encoding are: varint, 64bit, length-delimited, 32bit
   4. bytes are encoded using varint - simple technique to save space - should be supported in our bpf library
   5. although there are different types (named wire types) such as strings. Those has special header that represents them "(field_number << 3) | wire_type"
      6. after the header we can access information as we which - for strings, the next byte is the length and after that the byte sequence
5. Important finding regarding field order "When a message is serialized, there is no guaranteed order for how its known or unknown fields will be written. Serialization order is an implementation detail, and the details of any particular implementation may change in the future. Therefore, protocol buffer parsers must be able to parse fields in any order" - from https://developers.google.com/protocol-buffers/docs/encoding#packed
   1. This does not actually jeopardize the project only mean we should be careful with our constructions of eBPF (should not assume field orders)

## Relevant Work on the subject of eBPF:
1. Support better semantic rules and usage (relevant for our project because we aspire to create easier way to create semantic rules ontop of protobuf):
   1. Basic kernel and user space support with bpf.h and libbpf
      1. essentially making it slightly easier to write as it had c macros wrapping the instruction set
      2. still its like writing assembly with macros - pretty ugly :stuck_out_tongue:
   2. The LLVM support for higher abstraction layer over eBPF
      1. LLVM lets us write a C like program that will actually be compiled into an ELF
      2. This gives us the ability to separate the entities in the process of creating a eBPF program like:
         1. separate backend and data structure from the loader and frontend
      3. Is still pretty hard for every day usage like we intend it to be
   3. BCC and BCC-tools (https://github.com/iovisor/bcc/blob/master/docs/tutorial.md - very good tutorial)
      1. using python (finally) this creates the abstraction for the loader and frontend (without any C)
      2. The backend and data structures still defines C code which can be hard to understand or extend (complete C files inside .py)
         1. although the loader frontend are much more concise and simple to use, write and understand
      3. Because we are now using python we are on the safer side of the frontend and loader (no more null dereferences, etc.)
      4. so still pretty ugly :stuck_out_tongue:
   4. BPFftrace
      1. very limited but easy to write and run one-liner AWK like bpf programs
   5. Final level - IOVisor - eBPF technology in the Cloud (and other buzz words)
      1. New terminology
         1. backend becomes -> IO Visor Runtime Engine
         2. compiler backends -> IO Visor Compiler backends
         3. eBPF programs are now -> IO modules
         4. packet filter's eBPF programs become -> IO data-plane modules/components
      2. IO Modules Manager -> Hover - userspace deamon for managing eBPF programs
         1. capable of pushing and pulling IO modules to the cloud, similar to how Docker daemon publishes/fetches images
         2. Can be very useful for our project I guess
         3. There is a web REST API for this but it is very limiting and was written ontop of GO in addition to the BCC
2. Inspect packets with eBPF to achieve better performance (relevant for our project because we aspire to improve performance by processing protobuf information in eBPF programs)
   1. https://cilium.io/ - looks very promising essentially "eBPF-based Netowrking, Observability, and Security"
      1. open source - which can be very good for us to draw ideas from
      2. looks like they are sitting in the exact point with the exact tool (eBPF) as our intentions
      3. But - our project still adds the layer of semantic protobuf rules, better yet, we are looking deep into the application layer and not stopping at the IP/TCP stack as cilium
      4. Still, this looks very promising and there service does include looking at protocols like HTTP, Kafka
      5. Written in GO
   2. Sidecar and Shared Library Models (https://isovalent.com/blog/post/2021-12-08-ebpf-servicemesh - very good article on the subject)
      1. The mesh functionality will not be inside the applications but on the side (sidecar) like a proxy
      2. takes the responsibility for each app to implement its own mesh functionality
      3. Improved suggestion - move the sidecar mesh proxy into the kernel instead of a side library
      4. Kube-proxy - the first "service mesh" in the kernel
         6. however, Kube-proxy operates exclusively on the network packet level - lacks L7 support (Load balancing, rate limiting, and resiliency must be L7-aware (HTTP, REST, gRPC, WebSocket, …)
   3. The advantages that eBPF provides is the ability to be loaded securely and during runtime with a very powerful set of tools, like Kernel modules, but secured.
      1. Envoy also supports service mesh that is aware of the different tenants it hosts (providing even better functionalities and abilities)

## Relevant work on the subject of protobufs + eBPF:
BUG: kernel NULL pointer dereference, address: 0000000000000000

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

# Results:

## The difference between server_without_filter and server_with_filter

The server_without_filter calls additional function to validate the packet (_process_with_container_filter) While the server_with_filter does not because this filter was already applied in the eBPF filter.

## Was the eBPF filter faster?

Measured the diff in time from the: "Started Session" log to the last "Handled!"

On 2000 packets send on loopback (half should be filtered out):

With eBPF filter: approx time is 44.5 seconds

Without eBPF filter: approx time is 45.3 seconds

### Possible Explanations

Unfortunately, results were inconclusive regarding the benefit of using eBPF.
This can come from the fact that the current eBPF rule is very simple and does not save alot of cycles in the process. In addition, the need to log/ time from within the system (was done for simplistic reasons) might affect the processing time, since printing is a very intensive functionality.

# Retrospective

In retrospective I think I would have gone to probably implementing the protobuf rules to instructions instead of the BCC framework C code because I thinks that would have given me the ability to implement advance rules without unreadable error messages when trying to load the eBPF.
Although I must say that probably the BCC is right for the timeframe of this project because implementing a compiler in a few weeks with the load, backend and everything BCC takes care for would have been a real challenge.
This project for one person in the time frame, to me, was a lot more complicated than expected.


# Summary

I have learned alot about the use of eBPFs as socket filters, the BCC framework, debugging compiled eBPFs, protobuf, protobuf's encodings and that timing differences is super hard to measure!
This has been an amazing opportunity for me to develop a full-sized project's POC (lol) including containers to run client/ server, simple compiler from basic protobuf rules to eBPFs and loading that and trying to time it.

I hope this repo and the proto2ebpf repo will help developers who are just getting started with eBPFs and BCC framework as I provided a simple guide to get started on you clean Ubuntu 18.04.

I am still a strong believer that this method is faster than the container's enforcement and the only reason why I could not prove this currently is due to the fact that this project had to be submitted by a certain deadline, see future work for more on that.

# Future work

I am a strong believer in this approach, performance-wise and security-wise (vulnerabilities in the application will not be exploited if certain packets will be dropped by the kernel instead of reaching the parser and validators).
I will continue my research and provide a more accurate and complex result with the hope of proving that using eBPF will speed the validation of protocols implemented over protobuf.


Amit.

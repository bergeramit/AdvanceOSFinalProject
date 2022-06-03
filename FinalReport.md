# Advance OS Project Report

# Content

1. Introduction
    1. Introduction
    2. General Problem
    3. Goal
    4. Challenges
2. Getting Started
    1. Prier Knowledge & Work
    2. This Project
3. Deep Dive
    1. Setup
    2. Features
    3. Results
4. Summary
    1. Retrospective
    2. Future Work
    3. Summary
    4. Resources

# 1. Introuction

## 1.1. Introduction

This project aims to prove that an alternative solution, proposed by this paper, that changes the way applications enforce policies, can improve the application’s performace and security and also to provide developers with the first steps of implementing faster and more secured policy rule enforcements.

## 1.2. General Problem

Current app policies, such as login, must first retrieve the user input’s information, parse it, understand it, and then decide whether this message complied with the policy or not. This process has several built-in flaws.

### 1.2.1. Time Consuming

Parsing and processing every input message to check for compliacy is very time-consuming.
For example, every login attempt costs the server time to process the message, test for valid inputs, search database to find user’s profile and match the passwords and username, most of the times, more tests are needed to verify location, device used, etc. The process of retrieving the inputs and parsing them has became a more and more time consuming task in light of the rise of Dockers and Containers - which is now considered state-of-the-art platforms for application’s environment. This overhead is due to the fact that multiple docker’s can run on the same physical server and have the same IP address, which means, additional information needs to be processed in order to get to the app’s policy section (such as distributing every input to the currect container).
While the policy enforcing process must be done in order to validate a user, the process of discarding invalid credentials, for example - an input password of length 2 when the minimun password length is 4, can be sped up.

### 1.2.2. Security Flaws

A highly used attack surface for hackers these days involve trying to trick application’s policies into unathorized logins or leaking information. A solution for this problem will not be tested in this project but is believed to be solved by the proposed method.

## 1.3. Goal

This project’s goal is to find a faster and more secure way to implement application-level policies by moving policy rules from the application’s evironment to the kernel’s environment where they can be validated much faster and more secured (malicious attempts will not reach the application). 

More specifically, this project is aimed to determine and prove that eBPF code that will enforce rules regarding protobufs will be faster than writing those restrictive rulse in the containers. This will help future applications to scale with the use of the protobuf-to-ebpf library.

### 1.3.1. The Scope

This project focuses only on applications that are deployed on containers and uses protobuf objects as their means of communication.

In order to be able to test and validate the project we narrowed the scope to applications running on containers that uses protobuf objects as a way to transferring information between clients and servers. The project aims to tranform these protobuf based policy rules into eBPFs that will be loaded into the kernel of the server and thus creating the faster and more secured enforcement.
Both eBPFs and protobufs will be  explained in section 2.1.

## 1.4. Challenges

There are two challenges to this project: translating application level rules into eBPFs and testing and proving validity of this solution.

### 1.4.1. translating application level rules into eBPFs

The challenge here stems from the fact that in the application’s world (space) we have all the knowledge we need, we have the state, the databases access to more containers and applicatoins, and more, while in the eBPF world we are only relying on a very small amount of memory and almost no knowledge of the applications state. In other words, we need to translate semantic and full context meaning of policy rules into the contextless world of eBPFs.

### 1.4.2. testing and proving validity of this solution

In order to prove eBPF rules are faster than application based we want to prove that processing the same input message in the application and in the eBPF result in significant time differences between the two. This means we need to measure accurately the time it took for both methods. Because eBPFs are loaded into the kernel, timing them can be a problem and matching the time precision with that of the application’s timer is another challenge this project has.

# 2. Getting Started

## 2.1. Prier Knowledge & Work

### 2.1.1. eBPF

Extended Berkeley Packet Filter (eBPF) [3] is a kernel technology that allows programs to run without having to change the kernel source code or adding additional modules. You can think of it as a lightweight, sandbox virtual machine (VM) inside the Linux kernel, where programmers can run BPF bytecode that takes advantage of specific kernel resources.

#### 2.1.1.1. Capabilities of eBPFs

1. Registers and stack
   1. 11 64-bit registers
   2. 9 general purpose
   3. 1 PC
   4. 1 512 byte stack register
2. supports 32 bit architectures as well as 64 bit
3. can support up to 8 byte load/store instructions
4. Function calls can have at most 5 parameters
5. every pointer must be to a stack (no free address pointers)
6. Can access maps and contexts - can be shared
7. includes around 100 inst (mainly mov, store, load, calculations and conditional jumps)
8. no loops
9. must have at most 4096 instructions in each eBPF VM
10. Compiler
   1. compiles into bytecode so can be ran on a 32bit systems as well (cross platform)
   2. JIT in kernel


## 2.1.2. Protobuf

Protocol buffers are Google’s [4] language-neutral, platform-neutral, extensible mechanism for serializing structured data – think XML, but smaller, faster, and simpler. You define how you want your data to be structured once, then you can use special generated source code to easily write and read your structured data to and from a variety of data streams and using a variety of languages.

### 2.1.2.1. Capabilities of Protobuf

1. language-neutral, platform-neutral, extensible mechanism for serializing structured data
2. encodes into bytes
3. out-of-the-box support for python and GO (potentially one of the desired languages for this project)
4. well documented encoding scheme [5]
   1. based on bit operations - can be easily done with the eBPF instruction set
   2. key value pairs all the way down
   3. types of encoding are: varint, 64bit, length-delimited, 32bit
   4. bytes are encoded using varint - simple technique to save space - should be supported in our bpf library
   5. although there are different types (named wire types) such as strings. Those has special header that represents them “(field_number << 3) | wire_type”
      6. after the header we can access information as we which - for strings, the next byte is the length and after that the byte sequence
5. Important finding regarding field order “When a message is serialized, there is no guaranteed order for how its known or unknown fields will be written. Serialization order is an implementation detail, and the details of any particular implementation may change in the future. Therefore, protocol buffer parsers must be able to parse fields in any order” [7]
   1. This does not actually jeopardize the project only mean we should be careful with our constructions of eBPF (should not assume field orders)


## 2.1.3. Related Work

Relevant Work on the subject of eBPF:

1. Support better semantic rules and usage (relevant for our project because we aspire to create easier way to create semantic rules ontop of protobuf):
   1. Basic kernel and user space support with bpf.h and libbpf
      1. essentially making it slightly easier to write as it had c macros wrapping the instruction set
      2. still its like writing assembly with macros
   2. The LLVM support for higher abstraction layer over eBPF
      1. LLVM lets us write a C like program that will actually be compiled into an ELF
      2. This gives us the ability to separate the entities in the process of creating a eBPF program like:
         1. separate backend and data structure from the loader and frontend
      3. Is still pretty hard for every day usage like we intend it to be
   3. BCC and BCC-tools [6]
      1. using python (finally) this creates the abstraction for the loader and frontend (without any C)
      2. The backend and data structures still defines C code which can be hard to understand or extend (complete C files inside .py)
         1. although the loader frontend are much more concise and simple to use, write and understand
      3. Because we are now using python we are on the safer side of the frontend and loader (no more null dereferences, etc.)
   4. BPFftrace
      1. very limited but easy to write and run one-liner AWK like bpf programs
   5. Final level - IOVisor - eBPF technology in the Cloud (and other buzz words)
      1. New terminology
         1. backend becomes -> IO Visor Runtime Engine
         2. compiler backends -> IO Visor Compiler backends
         3. eBPF programs are now -> IO modules
         4. packet filter’s eBPF programs become -> IO data-plane modules/components
      2. IO Modules Manager -> Hover - userspace deamon for managing eBPF programs
         1. capable of pushing and pulling IO modules to the cloud, similar to how Docker daemon publishes/fetches images
         2. Can be very useful for our project I guess
         3. There is a web REST API for this but it is very limiting and was written ontop of GO in addition to the BCC
2. Inspect packets with eBPF to achieve better performance (relevant for our project because we aspire to improve performance by processing protobuf information in eBPF programs)
   1. Cilium [8] - looks very promising essentially “eBPF-based Netowrking, Observability, and Security”
      1. open source - which can be very good for us to draw ideas from
      2. looks like they are sitting in the exact point with the exact tool (eBPF) as our intentions
      3. But - our project still adds the layer of semantic protobuf rules, better yet, we are looking deep into the application layer and not stopping at the IP/TCP stack as cilium
      4. Still, this looks very promising and there service does include looking at protocols like HTTP, Kafka
      5. Written in GO
   2. Sidecar and Shared Library Models [9]
      1. The mesh functionality will not be inside the applications but on the side (sidecar) like a proxy
      2. takes the responsibility for each app to implement its own mesh functionality
      3. Improved suggestion - move the sidecar mesh proxy into the kernel instead of a side library
      4. Kube-proxy - the first “service mesh” in the kernel
         6. however, Kube-proxy operates exclusively on the network packet level - lacks L7 support (Load balancing, rate limiting, and resiliency must be L7-aware (HTTP, REST, gRPC, WebSocket, …)
   3. The advantages that eBPF provides is the ability to be loaded securely and during runtime with a very powerful set of tools, like Kernel modules, but secured.
      1. Envoy also supports service mesh that is aware of the different tenants it hosts (providing even better functionalities and abilities)


## 2.2. This Project

### 2.2.1. Repos

Projects repo (includes this report and the research journal):
```
https://github.com/bergeramit/AdvanceOSFinalProject.git
```

Main repo: contains the implementation of translating simple protobuf rules into eBPFs with the example and testing ground of the server-client search query code.
```
https://github.com/bergeramit/proto2ebpf.git
```

### 2.2.2. Research Journal

For those of you that would like to follow the process of exploring and building the environment yourselves can follow the Journal guide in the main repo under “Final Jounal”.

# 3. Deep Dive

## 3.1. Setup

In order to try and reproduce the results follow the instructions below to set up the testing environment.


You will need a server with protobuf filter
```
sudo docker container exec -it <CONTAINER_ID> /bin/bash
python3.6 proto2ebpf.py --env=server_with_filter
```

For comparison you should initialize another server without protobuf filter:
```
sudo docker container exec -it <CONTAINER_ID> /bin/bash
python3.6 proto2ebpf.py --env=server_without_filter
```

To run a client against those servers
```
sudo docker container exec -it <CONTAINER_ID> /bin/bash
python3.6 proto2ebpf.py --env=client
```

## 3.2. Features

### 3.2.1. What this setup actually have?

First this setup runs two servers, both of which has a simple search requests policy. However, one of the servers enforces this policy using eBPFs while the other uses simple python program to do so. (see server_app.py
)
Both servers run as docker containers and are set to be in the same network as the client. (see the docker files and command line arguments)

Our client is a simple testing script that will send a-lot of queries to the two servers and log the time it took for each to respond. (see client_app.py)

### 3.2.2. What are the policy?

We tested a simple black character policy - which means, if the client send the character ‘A’ that the query should be discarded.

### 3.2.3. Testing Parameters

Host (server and client): Ubuntu 18.04, 64bit

Queries sent: 2000

Queries that should be filtered out: 1000 (half)

Network topology: loopback

Server and Client environment: both were programed using 
python3

eBPF compiled: BCC compiler

## 3.3. Results

### 3.3.1. The difference between server_without_filter and server_with_filter

The server_without_filter calls additional function to validate the packet (_process_with_container_filter) While the server_with_filter does not because this filter was already applied in the eBPF filter.

### 3.3.2. Was the eBPF filter faster?

Measured the diff in time from the: “Started Session” log to the last “Handled!”

On 2000 packets send on loopback (half should be filtered out):

With eBPF filter: approx time is 44.5 seconds

Without eBPF filter: approx time is 45.3 seconds

### 3.3.3. Possible Explanations

Unfortunately, results were inconclusive regarding the benefit of using eBPF.
This can come from the fact that the current eBPF rule is very simple and does not save a-lot of cycles in the process. In addition, the need to log/ time from within the system (was done for simplistic reasons) might affect the processing time, since printing is a very intensive functionality.

# 4. Summary

## 4.1. Retrospective

In retrospective I think I would have gone to probably implementing the protobuf rules to instructions instead of the BCC framework C code because I thinks that would have given me the ability to implement advance rules without unreadable error messages when trying to load the eBPF.
Although I must say that probably the BCC is right for the timeframe of this project because implementing a compiler in a few weeks with the load, backend and everything BCC takes care for would have been a real challenge.
This project for one person in the time frame, to me, was a lot more complicated than expected.

## 4.2. Future Work

I am a strong believer in this approach, performance-wise and security-wise (vulnerabilities in the application will not be exploited if certain packets will be dropped by the kernel instead of reaching the parser and validators).
I will continue my research and provide a more accurate and complex result with the hope of proving that using eBPF will speed the validation of protocols implemented over protobuf.


## 4.3. Summary

I have learned a-lot about the use of eBPFs as socket filters, the BCC framework, debugging compiled eBPFs, protobuf, protobuf’s encodings and that timing differences is super hard to measure!
This has been an amazing opportunity for me to develop a full-sized project’s POC (lol) including containers to run client/ server, simple compiler from basic protobuf rules to eBPFs and loading that and trying to time it.

I hope this repo and the proto2ebpf repo will help developers who are just getting started with eBPFs and BCC framework as I provided a simple guide to get started on you clean Ubuntu 18.04.

I am still a strong believer that this method is faster than the container’s enforcement and the only reason why I could not prove this currently is due to the fact that this project had to be submitted by a certain deadline, see future work for more on that.


# 4. Resources

1. Main Repo: proto2ebpf - https://github.com/bergeramit/proto2ebpf.git
2. Report and research journal of this project: https://github.com/bergeramit/AdvanceOSFinalProject.git
3. eBPF intro: https://ebpf.io/
4. Protocol Buffers: https://developers.google.com/protocol-buffers
5. eBPF encoding scheme documentation: https://developers.google.com/protocol-buffers/docs/encoding#packed
6. BCC Tutorial and Documentation: https://github.com/iovisor/bcc/blob/master/docs/tutorial.md
7. Protocol Buffer encoding scheme: https://developers.google.com/protocol-buffers/docs/encoding#packed
8. Cilium Project: https://cilium.io/
9. Sidecar and Shared Library Models: https://isovalent.com/blog/post/2021-12-08-ebpf-servicemesh
FROM ubuntu:18.04

ENV RISCV=/opt/riscv
ENV PATH=$RISCV/bin:$PATH
ENV MAKEFLAGS=-j4

WORKDIR $RISCV

# 基本ツールのインストール
RUN apt update && \
    apt install -y autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk \
    build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev \
    pkg-config git libusb-1.0-0-dev device-tree-compiler default-jdk gnupg vim

# riscv-gnu-toolchinのビルド
RUN git clone --single-branch https://github.com/riscv-collab/riscv-gnu-toolchain.git
RUN cd riscv-gnu-toolchain && git submodule update --init --recursive binutils
RUN cd riscv-gnu-toolchain && git submodule update --init --recursive gcc
RUN cd riscv-gnu-toolchain && git submodule update --init --recursive newlib
RUN cd riscv-gnu-toolchain && git submodule update --init --recursive gdb
RUN cd riscv-gnu-toolchain && \
    mkdir build && \
    cd build && \
    ../configure --prefix=${RISCV} --enable-multilib && \
    make

# riscv-testsのダウンロード
RUN git clone -b master --single-branch https://github.com/riscv/riscv-tests && \
    cd riscv-tests && \
    git submodule update --init --recursive

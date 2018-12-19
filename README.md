# crystal_musl

## What is it?

A wrapper for the crystal compiler to automate the process of building
crystal programs and statically-linking them with musl and native
libraries that have been built with musl.

This has only been used/tested on a `x86_64-linux-gnu` system with
crystal 0.27.

## Why?

I wanted to see if it was possible to set up a build environment on my machine
to create statically-linked programs with crystal without having to build them
in a vm or a container (e.g., in alpine linux using docker) to simplify the
process of deploying a couple simple crystal utilities to low-resource machines
that are not my primary development machine. 

## Dependencies

  * crystal
  * a full gcc toolchain, make, etc
  * musl
  * musl-gcc
  * curl - used by the `Makefile` to fetch sources of libgc, libevent and libpcre

## Installation

(1) First install crystal. The scripts only work if the user running the
    scripts has write access to the folder where crystal is installed.

    I suggest installing crystal somewhere in your $HOME from the binary
    tarball for your platform that is provided on their project page.

    If you want to install this to a separate directory, you can explicitly set
    the installation PREFIX prior to compiling and installing the library
    dependencies. By default, the Makefile will look for a `crystal` executable
    on the path, get the absolute path, infer the crystal installation root
    from there, and then install its parts in there. It does not overwrite
    any parts of a core crystal installation.

(2) You need to have musl installed on your machine. You should also install
    a wrapper for gcc that compiles with musl. On debian (and probably other
    debian-based distros), you can just install the `musl`, `musl-tools`,
    and `musl-dev` packages. I have only used this on debian buster.

(3) Use the provided `Makefile` to download, compile, and install all libraries
    on which crystal programs depend using musl.

Run `make help` to see usage.

## Parts

The simple `Makefile` will install the `crystal_musl` compiler wrapper script to:

  `CRYSTAL_ROOT/bin`

And it will install all library dependencies that are compiled with `musl` to:

  `CRYSTAL_ROOT/lib/crystal_musl`

As of crystal 0.27, it seems that the minimum set of libraries that need to 
be linked to a crystal program are:

  * libc  (can be musl)
  * libgc (the boehm garbage collector)
  * libpcre  (perl compatible regular expression library v1)
  * libevent (crystal uses libevent to create an event loop for async io + its
    runtime scheduler, which is used by fibers)
  * libpthread (Crystal uses the pthread library internally in several areas.
    Since a version of libpthread.a ships with musl, this does not need to
    be installed separately if you already have musl)
  * librt    (real-time library for async io operations and also system clock
    functions. This is also distributed with musl)

When you run `make build`, the Makefile will compile `libgc`, `libpcre`, and
`libevent`, and these will be installed to `CRYSTAL_ROOT/lib/crystal_musl`
when you run `make install`. The latter target will also install
`CRYSTAL_ROOT/bin/crystal_musl`

## Usage

Assuming you have the following code in `hello.cr`:

```crystal
  puts "Hello World!"
```

You can compile it with:

```bash
crystal_musl build hello.cr     # or crystal_musl -o my_static_hello_world hello.cr
```

You can also use the standard crystal compiler flags like `--release`,
`--no-debug`, etc.

## How does it work?

`crystal_musl` is an executable shell script (similar to the `crystal` wrapper
script) that runs the crystal compiler with the `--cross-compile` option, and
after an object file is built, the wrapper script automatically statically links
it against library dependencies that have been compiled with musl in
`CRYSTAL_ROOT/lib/crystal_musl`.

## Disclaimer

I have only tried this with simple programs. It may completely blow up on
larger programs that actually use libevent, the garbage collector, or threads.

By default, the `Makefile` installs libgc v8.0.0, which (as of 2018-12-19),
is a very new version that the current maintainers say is experimental
and may not be stable. I did this because it is the first version that does
not depend on `libatomic_ops`, which does not compile out-of-the-box with
my version of musl + my musl-gcc toolchain.

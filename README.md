# container-build-scripts
Miscellaneous Scripts To Build App ACIs for different services

These repo assumes you're on a recent debian based linux system. In my case it's Ubuntu 16.04

## Dependencies
* `acbuild` Used to build the containers, available [here](https://github.com/containers/build)
* `systemd-nspawn` Used by `acbuild` in the build process. Can be installed using `apt install systemd-container`

## Building Containers
1. `cd` to the directory of the specific app
2. `./build-container.sh`
3. ACI should be in the current directory, if the build went okay

## Deploy Notes
ACIs follow a common spec so there are a number of tools to run them.
In My case I chose `rkt` from CoreOS. `rkt` is purely a tool to run
containers, not manage them. To set these containers up as services
on your system you will need to make use of something like systemd.
An example unit file has been included in the root of the repo.

Additonaly all the containers feature mounts for config, data, logs
and requisite direcotries to suite their opertion. Make sure to
either inspect the ACIs with the `rkt` tool or check the build
scripts to see what is available and needs to be configured for
the container to run properly.

One thing to take note of is the containers have been slightly
tailored to how __I__ think they should operate. As such there
are some configs inside the container build scripts. If a contianer
doesn't work how you'd like and you don't control the config outside
the container; take a poke around the build script and see if the
config you're looking for is there.

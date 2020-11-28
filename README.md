# container-build-scripts
Miscellaneous Scripts To Build Containers For Different Services

These repo assumes you have a few utilities installed to enable building container images

## Dependencies
* `curl` Used to download the base image tarballs
* `buildah` Used to build the containers, available [here](https://github.com/containers/build)
* `podman` Used by `run.sh` to start the container

## Building Containers
1. `cd` to the directory of the specific app
2. `./build-container.sh`
3. `./run.sh` Should start the container with some default volume mounts; these are just examples

## Deploy Notes
Containers can be deployed using any OCI compatible runtime e.g. [runc](https://github.com/opencontainers/runc) /
[cri-o](https://cri-o.io/). I prefer [podman](https://podman.io/) as it is a daemon-less container management
tool meaning no root background process 😁. The containers all have volumes for data and config so
that those can persist outside of the container lifetime.

### Self signed CAs
If you have any self signed CAs that you would like to use when connecting
over SSL to your own services, put them in the `cas` folder at the root.

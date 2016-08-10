
# Creating clean Docker image for npm builds

## Overview

Sometimes it can be difficult to create clean Docker images for
applications that have lots of build time dependencies.  Production
images may then end up containing extra packages, such as compilers,
that shouldn't really be there.  One approach is to write Dockerfiles
that first installs the dependencies, then builds the application and
finally removes unnecessary dependencies.  Another approach is to use
"builder" container.

This tutorial shows how to use an intermediate npm builder container
to produce clean Docker image for the web app, free of any build time
dependencies.

The basic idea is 2-step build (based on
[dockerception](https://github.com/jamiemccrindle/dockerception)):

1. Run npm build for the application inside a builder container.  The
   container should include all build time dependencies.  At the end
   of build, copy the results into a tar.gz package and export it from
   the container.  Include also a Dockerfile for the production image
   inside the tar.gz.

2. Run `docker build` to build the production container image by using
   the output of step 1 as
   "[build context](https://docs.docker.com/engine/reference/builder/)".

The end result is production container image that does not contain
e.g. nodejs, npm, babel which were required to build the
application.

The same basic approach works for other environments too, such as for
building clean Python application images.


## Build process

### 1. Build the application using the builder container

In first step we use [node](https://hub.docker.com/_/node/) image from
Docker hub as the builder container for our web application.  Custom
builder container might be more appropriate when extra OS packages
are required by the build but it is unnecessary in this case.

The build is executed by running following command in the root
directory of the repository:

    docker run --rm \
        --volume $PWD:/source:ro \
        --volume $HOME/cache:/cache \
        --volume $HOME/output:/output \
        node \
        /source/docker/builder.sh /output/myapp.tar.gz


The application source code is mounted as read-only at `/source/`.
Build script will create temporary read-write copy and run the build
within the working copy.  The build results will be stored into a
volume mounted at `/output/`.

Npm build will install a lot of [development time
dependencies](package.json) required by the build.  Note that these
are installed only into the builder container and they will not be
carried over to the final production Docker image.  To speed up the
installation on later builds we mount a directory from host at
`/cache/` and use it as a cache for npm.

The build is handled by script [docker/builder.sh](docker/builder.sh).
It also sets up npm cache on the cache volume.


### 2. Build the production container image

[NGINX](https://hub.docker.com/_/nginx/) image is used as the base for
the production image.  The pre-build application created at step 1 is
copied to the image.  See [docker/Dockerfile](docker/Dockerfile).

The build result from previous step (`$HOME/output/myapp.tar.gz`) is
used as Docker build context by this step.  This makes it unnecessary
to prepare temporary directory layout of files to be packaged on the
host system.  Instead, everything can be prepared inside the build
container, as was done in step 1.

Here is how to run the build with a tar.gz as context:

    docker build --tag myapp - < $HOME/output/myapp.tar.gz


And we are finished!  You can now test the image by starting it and
pointing your browser at [http://localhost:8080](http://localhost:8080).

    docker run --rm --publish 8080:80 myapp


## Acknowledgments

The example application used by this tutorial is based on splendid web
app template
[react-slingshot](https://github.com/coryhouse/react-slingshot) by
Cory House.  I have only added this `README.md` and whatever is found
under [docker](docker) directory.

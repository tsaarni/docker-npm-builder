#!/bin/bash -ex

# Create read-write working copy from read-only mounted source code
cp -ra /source /tmp/source

# Everything stored in /cache/ is mounted as a host volume for
# speeding up the build.
# We create cache directories for npm cache (~/.npm) and node_modules
mkdir -p /cache/npm-cache /cache/node_modules
ln -s /cache/npm-cache $HOME/.npm
ln -s /cache/node_modules /tmp/source/node_modules

# Now go to our working copy, install dependencies (most often already
# done due to cache) and build
cd /tmp/source
npm install
npm run build

# Install bundle to final destination directory
mkdir -p /output/usr/share/nginx/html
cp -a dist/* /output/usr/share/nginx/html

# Copy Dockerfile for production container image build into the root
# of destination directory
cp /source/docker/Dockerfile /output

# Finally package the build results.  The tar.gz package will be used
# as Docker build context by the production container image build.
tar -C /output -zcvf "${1-/output/build-results.tar.gz}" .

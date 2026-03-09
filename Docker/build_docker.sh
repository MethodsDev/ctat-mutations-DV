#!/bin/bash

set -e

VERSION=`cat VERSION.txt`

# Build from parent directory context to include .git and all source files
docker build -f Dockerfile -t trinityctat/ctat_mutations:$VERSION ..
docker build -f Dockerfile -t trinityctat/ctat_mutations:latest ..



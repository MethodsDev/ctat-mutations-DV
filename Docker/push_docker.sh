#!/bin/bash

set -e

VERSION=`cat VERSION.txt`

docker push trinityctat/ctat_mutations_dv:${VERSION}
docker push trinityctat/ctat_mutations_dv:latest



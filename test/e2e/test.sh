#!/bin/bash

# Copyright 2018 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Vendoring the e2e framework is too hard. Download kubernetes source, patch
# our tests on top of it, build and run from there.

KUBE_VERSION=1.11.0
TEST_DIR=$GOPATH/src/github.com/pgitlarski/nfs-ganesha-server-and-external-provisioner/test/e2e

GOPATH=$TEST_DIR

# Download kubernetes source
if [ ! -e "$GOPATH/src/k8s.io/kubernetes" ]; then
  mkdir -p $GOPATH/src/k8s.io
  curl -L https://github.com/kubernetes/kubernetes/archive/v${KUBE_VERSION}.tar.gz | tar xz -C $TEST_DIR/src/k8s.io/
  rm -rf $GOPATH/src/k8s.io/kubernetes
  mv $GOPATH/src/k8s.io/kubernetes-$KUBE_VERSION $GOPATH/src/k8s.io/kubernetes
fi

cd $GOPATH/src/k8s.io/kubernetes

# Clean some unneeded sources
find ./test/e2e -maxdepth 1 -type d ! -name 'e2e' ! -name 'framework' ! -name 'manifest' ! -name 'common' ! -name 'generated' ! -name 'testing-manifests' ! -name 'perftype' -exec rm -r {} +
find ./test/e2e -maxdepth 1 -type f \( -name 'examples.go' -o -name 'gke_local_ssd.go' -o -name 'gke_node_pools.go' \) -delete
find ./test/e2e/testing-manifests -maxdepth 1 ! -name 'testing-manifests' ! -name 'BUILD' -exec rm -r {} +

# Copy our sources
mkdir ./test/e2e/storage
cp $TEST_DIR/nfs.go ./test/e2e/storage/
rm ./test/e2e/e2e_test.go
cp $TEST_DIR/e2e_test.go ./test/e2e/
cp -r $TEST_DIR/testing-manifests/* ./test/e2e/testing-manifests

# Build e2e.test
./build/run.sh make KUBE_BUILD_PLATFORMS=linux/amd64 WHAT=test/e2e/e2e.test &> /dev/null

# Download kubectl to _output directory
if [ ! -e "$HOME/bin/kubectl" ]; then
  curl -o $HOME/bin/kubectl -LO https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
  chmod +x $HOME/bin/kubectl
fi

# Run tests assuming local cluster i.e. one started with hack/local-up-cluster.sh
./_output/dockerized/bin/linux/amd64/e2e.test --provider=local --ginkgo.focus=external-storage --kubeconfig=$HOME/.kube/config

#!/bin/bash
# This file is meant to be included by the parent cppbuild.sh script
if [[ -z "$PLATFORM" ]]; then
    pushd ..
    bash cppbuild.sh "$@" tensorflow
    popd
    exit
fi

case $PLATFORM in
    linux-x86)
        export BUILDFLAGS="--copt=-m32 --linkopt=-m32"
        ;;
    linux-x86_64)
        export BUILDFLAGS="--copt=-m64 --linkopt=-m64"
        ;;
    macosx-*)
        export BUILDFLAGS="--linkopt=-install_name --linkopt=@rpath/libtensorflow.so"
        ;;
    *)
        echo "Error: Platform \"$PLATFORM\" is not supported"
        return 0
        ;;
esac

# Hardcoding a release of TF, because the API changes a lot and the cpp header list if out of date.
# Release 0.6.0 is incompatible with bazel >= 0.1.5, so using a pre-release of 0.7 instead.
TENSORFLOW_VERSION="v0.7.1"
TENSORFLOW_PATCH_VERSION="0.7.1"

#download https://github.com/google/protobuf/archive/v$PROTOBUF_VERSION.tar.gz protobuf-$PROTOBUF_VERSION.tar.gz
#download https://github.com/tensorflow/tensorflow/archive/v$TENSORFLOW_VERSION.tar.gz tensorflow-$TENSORFLOW_VERSION.tar.gz

mkdir -p $PLATFORM
cd $PLATFORM

if [[ ! -e tensorflow ]]; then
    echo "Downloading tensorflow git repository"
    git clone --recurse-submodules https://github.com/tensorflow/tensorflow.git
fi

echo "Checking out TF version"
cd tensorflow
git remote update
git submodule update
git checkout $TENSORFLOW_VERSION
# This will only reset the potentially patched files, but it will not remove temporary files.
# Bazel seems to be good enough to know what to recompile without having to do a full clean.
git reset --hard


#echo "Decompressing archives"
#tar --totals -xzf ../protobuf-$PROTOBUF_VERSION.tar.gz
#tar --totals -xzf ../tensorflow-$TENSORFLOW_VERSION.tar.gz

# Assumes Bazel is available in the path: http://bazel.io/docs/install.html
#cd tensorflow-$TENSORFLOW_VERSION/google
#cd google
#rmdir protobuf || true
#ln -snf ../../protobuf-$PROTOBUF_VERSION protobuf
#cd ..
patch -Np1 < ../../../tensorflow-$TENSORFLOW_PATCH_VERSION.patch
./configure

# This is the base command:
# The location of the output is important to access the protobuf outputs.
bazel --output_base=bazel_output build -c opt --fetch=true //tensorflow/cc:libtensorflow.so $BUILDFLAGS
# If you run in docker with a mounted directory, or if you have already downloaded all the dependencies,
# you can short-circuit the previous outputs.
#bazel --output_base=/root/bazel-tf-out  build --fetch=true //tensorflow/cc:libtensorflow.so $BUILDFLAGS

cd ../..

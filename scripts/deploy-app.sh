#!/bin/bash
# deploy PACM app to remote server

set -eu

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

DIR=${2:-"${HOME}/data/pacm/app"}
FILENAME="pacm-app-$VERSION.tar.gz"

# create tar.gz file
echo "Creating $FILENAME from $DIR..."
tar -czvf $DIR/$FILENAME --exclude data/ -C dist .
echo

# copy to gcs
echo "Copying $FILENAME to gs://nmfs_pacm/app/..."
gsutil cp $DIR/$FILENAME gs://nmfs_pacm/app/$FILENAME

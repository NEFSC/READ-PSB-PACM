#!/bin/bash
# update PACM app on remote server

set -eu

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  exit 1
fi

FILENAME="pacm-app-$VERSION.tar.gz"
URI="gs://nmfs_pacm/app/${FILENAME}"

# copy from remote
echo "Copying app from $URI..."
gsutil -m cp -r $URI ./

# create directory
echo "Creating directory $VERSION..."
mkdir -p $VERSION

# extract to folder
echo "Extracting app to $VERSION..."
tar -xzf $FILENAME -C $VERSION

# update current symlink
echo "Updating current symlink to $VERSION..."
ln -sfn $VERSION current

# update permissions
echo "Setting permissions for $VERSION and current..."
chmod -R 755 $VERSION current

echo "App update complete. Current app is now available in the 'current' directory."

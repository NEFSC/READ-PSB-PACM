#!/bin/bash
# update PACM data on remote server

set -eu

DATE=${1:-"$(date +%Y%m%d)"}
FILENAME="pacm-data-$DATE.tar.gz"
URI="gs://nmfs_pacm/data/${FILENAME}"

# copy from remote
echo "Copying data from $URI..."
gsutil -m cp -r $URI ./

# create directory
echo "Creating directory $DATE..."
mkdir -p $DATE

# extract to folder
echo "Extracting data to $DATE..."
tar -xzf $FILENAME -C $DATE

# update current symlink
echo "Updating current symlink to $DATE..."
ln -sfn $DATE current

# update permissions
echo "Setting permissions for $DATE and current..."
chmod -R 755 $DATE current

echo "Data update complete. Current data are now available in the 'current' directory."

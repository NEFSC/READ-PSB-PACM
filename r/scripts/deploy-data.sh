#!/bin/bash
# package and copy data to gcs

DIR=${1:-"${HOME}/data/pacm/data"}
DATE=$(date +%Y%m%d)
FILENAME="pacm-data-$DATE.tar.gz"

# create tar.gz file
echo "Creating $FILENAME from $DIR..."
tar -czvf $FILENAME -C $DIR . 
echo

# copy to gcs
echo "Copying $FILENAME to gs://nmfs_pacm/data/..."
gsutil cp $DIR/$FILENAME gs://nmfs_pacm/data/$FILENAME

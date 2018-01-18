#!/bin/bash

# DO NOT EDIT - This file is being maintained by Chef

# Before running updates, the replication needs to be set up with the timestamp
# set to the day of the latest planet dump. Setting to midnight ensures we get
# conistent data after first run. osmosis --read-replication-interval-init is
# used to initially create the state file

# Define exit handler
function onexit {
    [ -f state-prev.txt ] && mv state-prev.txt state.txt
}

# Change to the replication state directory
cd /rep_data/changesets

# Install exit handler
trap onexit EXIT

# Read in initial state
. state.txt

# Loop indefinitely
while true
do
    # Work out the name of the next file
    file="changes-${sequenceNumber}.osc.gz"

    # Save state file so we can rollback if an error occurs
    cp state.txt state-prev.txt

    # Fetch the next set of changes
    /osmosis/bin/osmosis --read-replication-interval --simc --write-xml-change file="${file}" compressionMethod="gzip"

    # Check for errors
    if [ $? -eq 0 ]
    then
        # Enable exit on error
        set -e

        # Remember the previous sequence number
        prevSequenceNumber=$sequenceNumber

        # Read in new state
        . state.txt

        # Did we get any new data?
        if [ "${sequenceNumber}" == "${prevSequenceNumber}" ]
        then
            # Log the lack of data
            echo "No new data available. Sleeping..."

            # Remove file, it will just be an empty changeset
            rm ${file}

            # No need to rollback now
            rm state-prev.txt

            # Sleep for a short while
            sleep 30
        else
            # Log the new data
            echo "Fetched new data from ${prevSequenceNumber} to ${sequenceNumber} into ${file}"

            # Apply the changes to the database
            osm2pgsql --host osm-dev-db --username postgres --database dev_gis --slim --append --number-processes=1 \
                      --flat-nodes=../nodes-cache/nodes \
                      --multi-geometry --hstore \
                      --style=/openstreetmap-carto/openstreetmap-carto.style \
                      --tag-transform-script=/openstreetmap-carto/openstreetmap-carto.lua \
                      ${file}

            # No need to rollback now
            rm state-prev.txt

            # Queue these changes for expiry processing
            ln ${file} ../expire-queue/$file
        fi

        # Delete old downloads
        find . -name 'changes-*.gz' -mmin +300 -exec rm -f {} \;

        # Disable exit on error
        set +e
    else
        # Log our failure to fetch changes
        echo "Failed to fetch changes - waiting a few minutes before retry"

        # Wait five minutes and have another go
        sleep 300
    fi
done
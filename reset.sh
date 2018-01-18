#!/bin/bash

docker run --rm -it -e PGPASSWORD=postgres --network osm_network postgres:9.5.10 \
       psql -h osm-dev-db -U postgres -c \
       'DROP DATABASE dev_gis;'

docker run --rm -it -e PGPASSWORD=postgres --network osm_network postgres:9.5.10 \
       psql -h osm-dev-db -U postgres -c \
       'CREATE DATABASE dev_gis;'

docker run --rm -it -e PGPASSWORD=postgres --network osm_network postgres:9.5.10 \
       psql -h osm-dev-db -U postgres -d dev_gis -c \
       'CREATE EXTENSION postgis; CREATE EXTENSION hstore;'

rm -rf ../data/changesets/*
rm -rf ../data/minutely-export/*
rm -rf ../data/nodes-cache/*
rm -rf ../data/expire-queue/*

tee ../data/minutely-export/state.txt << EOF
txnMaxQueried=0
sequenceNumber=0
timestamp=2015-01-01T00\:00\:00Z
txnReadyList=
txnMax=0
txnActiveList=
EOF

mkdir -p ../data/minutely-export/000/000

cp configuration.txt ../data/changesets/
cp ../data/minutely-export/state.txt ../data/changesets/state.txt
cp ../data/minutely-export/state.txt ../data/minutely-export/000/000/000.state.txt

docker run -v $(pwd)/../data:/rep_data \
           --rm \
           --workdir /rep_data/changesets \
           --network osm_network \
           --entrypoint /osmosis/bin/osmosis \
           osm/replicator \
           --read-replication-interval --simc --write-xml-change file="changes.osc.gz" compressionMethod="gzip"

docker run -v $(pwd)/../data:/rep_data \
           --rm \
           --workdir /rep_data/changesets \
           --network osm_network \
           --entrypoint osm2pgsql \
           osm/replicator \
            --create --host osm-dev-db --username postgres --database dev_gis --slim --number-processes=1 \
            --flat-nodes=../nodes-cache/nodes \
            --multi-geometry --hstore \
            --style=/openstreetmap-carto/openstreetmap-carto.style \
            --tag-transform-script=/openstreetmap-carto/openstreetmap-carto.lua \
            "changes.osc.gz"

rm -f ../data/changesets/changes.osc.gz

chmod -R 777 ../data/minutely-export ../data/changesets

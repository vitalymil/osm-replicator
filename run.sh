#!/bin/bash

docker rm -f osm-replicator
docker run -d -v $(pwd)/../data:/rep_data --name osm-replicator --network osm_network osm/replicator
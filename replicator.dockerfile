FROM osm/replicator-base

WORKDIR /

# Need to remove proxy config and change url to local Gitlab
RUN git clone https://github.com/gravitystorm/openstreetmap-carto.git

COPY osmosis-latest.tgz .
RUN mkdir osmosis
RUN mv osmosis-latest.tgz osmosis
WORKDIR /osmosis
RUN tar xvfz osmosis-latest.tgz
RUN rm osmosis-latest.tgz

ENV PGPASSWORD=postgres
ENV PGPASS=postgres

WORKDIR /
COPY export-cron /etc/cron.d/
COPY auth.conf .
RUN chmod 0644 /etc/cron.d/export-cron
COPY import-rep.sh .
RUN chmod 777 import-rep.sh
CMD cron && ./import-rep.sh
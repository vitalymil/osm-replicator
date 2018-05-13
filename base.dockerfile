FROM java:8
COPY apt.conf /etc/apt/
RUN apt-get update
RUN apt-get install -y make cmake g++ libboost-dev libboost-system-dev \
  libboost-filesystem-dev libexpat1-dev zlib1g-dev \
  libbz2-dev libpq-dev libproj-dev lua5.2 liblua5.2-dev cron osm2pgsql

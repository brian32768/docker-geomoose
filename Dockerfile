# GeoMoose for Docker
FROM ubuntu:trusty
MAINTAINER Dan "Ducky" Little <@theduckylittle>

ENV LANG C.UTF-8
RUN update-locale LANG=C.UTF-8

# Update and upgrade system
RUN apt-get -qq update --fix-missing && apt-get -qq --yes upgrade

# Install mapcache compilation prerequisites
RUN apt-get install -y software-properties-common g++ make cmake wget git openssh-server

# Install mapcache dependencies provided by Ubuntu repositories
RUN apt-get install -y \
    libxml2-dev \
    libxslt1-dev \
    libproj-dev \
    libfribidi-dev \
    libcairo2-dev \
    librsvg2-dev \
    libmysqlclient-dev \
    libpq-dev \
    libcurl4-gnutls-dev \
    libexempi-dev \
    libgdal-dev \
    libgeos-dev

# Install libharfbuzz from source as it is not in a repository
RUN apt-get install -y bzip2
RUN cd /tmp && wget http://www.freedesktop.org/software/harfbuzz/release/harfbuzz-0.9.19.tar.bz2 && \
    tar xjf harfbuzz-0.9.19.tar.bz2 && \
    cd harfbuzz-0.9.19 && \
    ./configure && \
    make && \
    make install && \
    ldconfig

# Apache 2
RUN apt-get update && apt-get install -y apache2 apache2-threaded-dev curl

# Configure localhost in Apache
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf
RUN echo "ErrorLog /dev/stdout" >> /etc/apache2/apache2.conf
COPY etc/000-default.conf /etc/apache2/sites-available/

# Install the Apache Worker MPM (Multi-Procesing Modules)
RUN sudo apt-get install apache2-mpm-worker

# To reconcile this, the multiverse repository must be added to the apt sources.
RUN echo 'deb http://archive.ubuntu.com/ubuntu trusty multiverse' >> /etc/apt/sources.list
RUN echo 'deb http://archive.ubuntu.com/ubuntu trusty-updates multiverse' >> /etc/apt/sources.list
RUN echo 'deb http://security.ubuntu.com/ubuntu trusty-security multiverse' >> /etc/apt/sources.list
RUN sudo apt-get update

# Enable these Apache modules
RUN sudo a2enmod actions cgi alias

# Install supervisor
RUN apt-get install -y supervisor
RUN mkdir -p /var/log/supervisor
COPY etc/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Install Mapserver itself
RUN git clone https://github.com/mapserver/mapserver/ /usr/local/src/mapserver

# Compile Mapserver for Apache
RUN mkdir /usr/local/src/mapserver/build && \
    cd /usr/local/src/mapserver/build && \
    cmake ../ -DWITH_THREAD_SAFETY=1 \
        -DWITH_PROJ=1 \
        -DWITH_KML=1 \
        -DWITH_SOS=1 \
        -DWITH_WMS=1 \
        -DWITH_FRIBIDI=1 \
        -DWITH_HARFBUZZ=1 \
        -DWITH_ICONV=1 \
        -DWITH_CAIRO=1 \
        -DWITH_RSVG=1 \
        -DWITH_MYSQL=1 \
        -DWITH_GEOS=1 \
        -DWITH_POSTGIS=1 \
        -DWITH_GDAL=1 \
        -DWITH_OGR=1 \
        -DWITH_CURL=1 \
        -DWITH_CLIENT_WMS=1 \
        -DWITH_CLIENT_WFS=1 \
        -DWITH_WFS=1 \
        -DWITH_WCS=1 \
        -DWITH_LIBXML2=1 \
        -DWITH_GIF=1 \
        -DWITH_EXEMPI=1 \
        -DWITH_XMLMAPFILE=1 \
    -DWITH_FCGI=0 && \
    make && \
    make install && \
    ldconfig

# Link to cgi-bin executable
RUN chmod o+x /usr/local/bin/mapserv
RUN ln -s /usr/local/bin/mapserv /usr/lib/cgi-bin/mapserv
RUN chmod 755 /usr/lib/cgi-bin

# Install TinyOWS

## First install postgresql and postgis

# RUN apt-get install -y autoconf build-essential cmake docbook-mathml docbook-xsl libboost-dev libboost-filesystem-dev libboost-timer-dev libcgal-dev libcunit1-dev libgdal-dev libgeos++-dev libgeotiff-dev libgmp-dev libjson0-dev libjson-c-dev liblas-dev libmpfr-dev libopenscenegraph-dev libpq-dev libproj-dev libxml2-dev postgresql xsltproc wget flex libfcgi-dev postgis postgresql-9.3-postgis-2.1


# Compile TinyOWS
# RUN git clone https://github.com/mapserver/tinyows.git
# RUN cd tinyows && autoconf && ./configure && make && make install && cp tinyows /usr/lib/cgi-bin/tinyows
# get rid of tinyows leftovers
# RUN rm -rf tinyows
#--with-shp2pgsql=/usr/lib/postgresql/9.5/bin/shp2pgsql 

# COPY etc/tinyows.xml /etc/tinyows.xml

# End of TinyOWS Install

# Get the database going

# create a landing place for the places data
# RUN mkdir -p /data/places
# RUN chmod a+rx /data
# RUN chmod a+rwx /data/places
# COPY data/places/* /data/places/

# now create a database and load the data into it.
# COPY createdb.sh /tmp
# RUN chmod +x /tmp/createdb.sh
# RUN sudo service postgresql start ; su - postgres -c "/tmp/createdb.sh"

## Install the GeoMoose demo data

# create a new directory
# RUN mkdir -p /data

# clone the data repo into a useful directory.
RUN sudo git clone https://github.com/geomoose/gm3-demo-data.git /data
RUN sudo chown www-data:www-data -R /data

# Restart Apache
RUN sudo service apache2 restart

EXPOSE 80

ENV HOST_IP `ifconfig | grep inet | grep Mask:255.255.255.0 | cut -d ' ' -f 12 | cut -d ':' -f 2`


CMD ["/usr/bin/supervisord"]

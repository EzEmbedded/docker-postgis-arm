FROM postgres:14-alpine3.16

LABEL maintainer="PostGIS Project - https://postgis.net"

ENV POSTGIS_VERSION 3.3.1
ENV POSTGIS_SHA256 12298af0ef8804d913d2e8ca726785d1dc1e51b9589ae49f83d2c64472821500



# https://github.com/pramsey/pgsql-gzip/releases
ARG PGSQL_GZIP_TAG=v1.0.0
ARG PGSQL_GZIP_REPO=https://github.com/pramsey/pgsql-gzip.git

# https://github.com/JuliaLang/utf8proc/releases
ARG UTF8PROC_TAG=v2.5.0
ARG UTF8PROC_REPO=https://github.com/JuliaLang/utf8proc.git

# osml10n - https://github.com/openmaptiles/mapnik-german-l10n/releases
ARG MAPNIK_GERMAN_L10N_TAG=v2.5.9.1
ARG MAPNIK_GERMAN_L10N_REPO=https://github.com/openmaptiles/mapnik-german-l10n.git

RUN set -eux \
    \
    &&  if   [ $(printf %.1s "$POSTGIS_VERSION") == 3 ]; then \
            set -eux ; \
            #
            # using only v3.16
            #
            #GEOS: https://pkgs.alpinelinux.org/packages?name=geos&branch=v3.16 \
            export GEOS_ALPINE_VER=3.10 ; \
            #GDAL: https://pkgs.alpinelinux.org/packages?name=gdal&branch=v3.16 \
            export GDAL_ALPINE_VER=3.5 ; \
            #PROJ: https://pkgs.alpinelinux.org/packages?name=proj&branch=v3.16 \
            export PROJ_ALPINE_VER=9.0 ; \
            #
        elif [ $(printf %.1s "$POSTGIS_VERSION") == 2 ]; then \
            set -eux ; \
            #
            # using older branches v3.13; v3.14 for GEOS,GDAL,PROJ
            #
            #GEOS: https://pkgs.alpinelinux.org/packages?name=geos&branch=v3.13 \
            export GEOS_ALPINE_VER=3.8 ; \
            #GDAL: https://pkgs.alpinelinux.org/packages?name=gdal&branch=v3.14 \
            export GDAL_ALPINE_VER=3.2 ; \
            #PROJ: https://pkgs.alpinelinux.org/packages?name=proj&branch=v3.14 \
            export PROJ_ALPINE_VER=7.2 ; \
            #
            \
            echo 'https://dl-cdn.alpinelinux.org/alpine/v3.14/main'      >> /etc/apk/repositories ; \
            echo 'https://dl-cdn.alpinelinux.org/alpine/v3.14/community' >> /etc/apk/repositories ; \
            echo 'https://dl-cdn.alpinelinux.org/alpine/v3.13/main'      >> /etc/apk/repositories ; \
            echo 'https://dl-cdn.alpinelinux.org/alpine/v3.13/community' >> /etc/apk/repositories ; \
            \
        else \
            set -eux ; \
            echo ".... unknown \$POSTGIS_VERSION ...." ; \
            exit 1 ; \
        fi \
    \
    && apk add -U --no-cache --virtual .fetch-deps \
        build-base \
        ca-certificates \
	git \
	# libgdal-dev \
	# libkakasi2-dev \
	# postgresql-server-dev-$PG_MAJOR \
	# pandoc \
        openssl \
        tar \
    \
    && wget -O postgis.tar.gz "https://github.com/postgis/postgis/archive/${POSTGIS_VERSION}.tar.gz" \
    && echo "${POSTGIS_SHA256} *postgis.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/src/postgis \
    && tar \
        --extract \
        --file postgis.tar.gz \
        --directory /usr/src/postgis \
        --strip-components 1 \
    && rm postgis.tar.gz \
    \
    && apk add --no-cache --virtual .build-deps \
        \
        gdal-dev~=${GDAL_ALPINE_VER} \
        geos-dev~=${GEOS_ALPINE_VER} \
        proj-dev~=${PROJ_ALPINE_VER} \
        \
        autoconf \
        automake \
        clang-dev \
        file \
        g++ \
        gcc \
        gettext-dev \
        json-c-dev \
        libtool \
        libxml2-dev \
        llvm-dev \
        make \
	cmake \
        pcre-dev \
        perl \
        protobuf-c-dev \
	# pandoc \
	# libgdal-dev \
    \
# build PostGIS
    \
    && cd /usr/src/postgis \
    && gettextize \
    && ./autogen.sh \
    && ./configure \
        --with-pcredir="$(pcre-config --prefix)" \
    && make -j$(nproc) \
    && make install \
    \	 
   ##
    ## gzip extension
    && mkdir -p /opt \
    && cd /opt/  \
    && git clone --quiet --depth 1 -b $PGSQL_GZIP_TAG $PGSQL_GZIP_REPO  \
    && cd pgsql-gzip  \
    && make  \
    && make install  \
    && rm -rf /opt/pgsql-gzip  \
    
   ## UTF8Proc
    && cd /opt/  \
    && git clone --quiet --depth 1 -b $UTF8PROC_TAG $UTF8PROC_REPO  \
    && cd utf8proc  \
    && make  \
    && make install  \
#    && ldconfig  \
    && rm -rf /opt/utf8proc  \
    ##
   ## osml10n extension (originally Mapnik German)
  #   && cd /opt/  \
  #   && git clone --quiet --depth 1 -b $MAPNIK_GERMAN_L10N_TAG $MAPNIK_GERMAN_L10N_REPO  \
  #   && cd mapnik-german-l10n  \
  #   && make  \
  #   && make install  \
  #   && rm -rf /opt/mapnik-german-l10n  \
  #   ##    
    
        			
																	   
					 
			
					
							  
	  
			   
				
																   
				   
			
					
				
							
	  
												   
				
																					   
							 
			
					
									  
		  
	
	
# buildx platform check for debug.
    && uname -a && uname -m && cat /proc/cpuinfo \
    \
# regress check
    && mkdir /tempdb \
    && chown -R postgres:postgres /tempdb \
    && su postgres -c 'pg_ctl -D /tempdb init' \
    \
    # QEMU7.0/BUILDX - JIT workaround
    && if [[ "$(uname -m)" == "aarch64" && "14" != "10" ]] || \
          [[ "$(uname -m)" == "ppc64le" && "14" != "10" ]]; then \
            set -eux \
            # for the buildx/qemu workflow
            #   with (aarch64 ppc64le) and PG>10 .. we are testing with JIT=OFF to avoid QEMU7.0/BUILDX error
            && echo "WARNING: JIT=OFF testing (aarch64 ppc64le)!" \
            && echo "## WARNING: tested with JIT=OFF (aarch64 ppc64le)!" >> /_pgis_full_version.txt \
            && su postgres -c 'pg_ctl -o "--jit=off" -D /tempdb start' \
            && su postgres -c 'psql -c "SHOW JIT;"' \
            ; \
        else \
            set -eux \
            # default test .. no problem expected.
            && su postgres -c 'pg_ctl -D /tempdb start' \
            ; \
        fi \
    \
    && cd regress \
    && make -j$(nproc) check RUNTESTFLAGS=--extension   PGUSER=postgres \
    #&& make -j$(nproc) check RUNTESTFLAGS=--dumprestore PGUSER=postgres \
    #&& make garden                                      PGUSER=postgres \
    \
    && su postgres -c 'psql    -c "CREATE EXTENSION IF NOT EXISTS postgis;"' \
    && su postgres -c 'psql -t -c "SELECT version();"'              >> /_pgis_full_version.txt \
    && su postgres -c 'psql -t -c "SELECT PostGIS_Full_Version();"' >> /_pgis_full_version.txt \
    \
    && su postgres -c 'pg_ctl -D /tempdb --mode=immediate stop' \
    && rm -rf /tempdb \
    && rm -rf /tmp/pgis_reg \
# add .postgis-rundeps
    && apk add --no-cache --virtual .postgis-rundeps \
        \
        gdal~=${GDAL_ALPINE_VER} \
        geos~=${GEOS_ALPINE_VER} \
        proj~=${PROJ_ALPINE_VER} \
        \
        json-c \
        libstdc++ \
        pcre \
        protobuf-c \
        \
        # ca-certificates: for accessing remote raster files
        #   fix https://github.com/postgis/docker-postgis/issues/307
        ca-certificates \
# clean
    && cd / \
    && rm -rf /usr/src/postgis \
    && apk del .fetch-deps .build-deps \
# print PostGIS_Full_Version() for the log. ( experimental & internal )
    && cat /_pgis_full_version.txt

COPY ./initdb-postgis.sh /docker-entrypoint-initdb.d/10_postgis.sh
COPY ./update-postgis.sh /usr/local/bin

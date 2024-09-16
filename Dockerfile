FROM python:3.12.4

ENV EXTENSION="jp2"
ENV OPERATION="deflate"
ENV NAME="output"
ENV GDAL_CACHE="2048"
ENV GDAL_WORKERS="2"

RUN apt update && apt install gdal-bin libgdal-dev python3-gdal -y \
    && apt clean \
    && apt -y autoclean \
    && apt -y autoremove \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/share/man/* \
    && rm -rf /usr/share/doc/*

RUN pip install --no-cache-dir pygdal==3.6.2.11 numpy

WORKDIR /usr/src/app

COPY scripts ./scripts
RUN chmod +x scripts/*.sh

COPY entrypoint.sh ./
RUN chmod +x entrypoint.sh

USER 1000

ENTRYPOINT [ "./entrypoint.sh" ]
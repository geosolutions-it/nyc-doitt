# NYC - DoiTT

## Introduction

This repository contains the code needed to build the Docker image [geosolutionsit/nyc-doitt](https://hub.docker.com/r/geosolutionsit/nyc-doitt) that provides a pre-configured environment with GDAL and Python libraries for processing raster geospatial images.  

## Prerequisites

* **Docker:** Make sure you have Docker installed and running on your system. You can download it from [https://www.docker.com/get-started](https://www.docker.com/get-started).

## Usage

The container is designed to run an operation on a single batch of data, the latter identified by a name.

```docker
docker run --rm -it \
    -v /absolute/path/to/your/host/data:/usr/src/app/input \
    -v /absolute/path/to/your/host/output:/usr/src/app/output \
    -e OPERATION="deflate" \
    -e NAME="manhattan" \
    geosolutionsit/nyc-doitt:1.0.0
```

- -v (Bind Mounts): Map your local input and output directories to the corresponding directories in the container.
- -e OPERATION: Specify the operation to perform: "deflate" or "compression". Defaults to "deflate".
- -e NAME: Provide a name for your output files. Defaults to "output" if not specified.

### Output

When specifiying "deflate" as the operation to perform, the output will be placed in the path bound to `usr/src/app/output`, inside a folder named as the `NAME` variable value, while when using "compression", the output will be a single `.tif` file named as the `NAME` value.
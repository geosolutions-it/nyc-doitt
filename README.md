# NYC - DoiTT

## Introduction

This repository contains the code needed to build the Docker image [geosolutionsit/nyc-doitt](https://hub.docker.com/r/geosolutionsit/nyc-doitt) that provides a pre-configured environment with GDAL and Python libraries for processing raster geospatial images.  

## Prerequisites

* **Docker:** Make sure you have Docker installed and running on your system. You can download it from [https://www.docker.com/get-started](https://www.docker.com/get-started).

## Usage

The container is designed to run an operation on a single batch of data, the latter identified by a name.

```docker
docker run --rm -t \
    -v /absolute/path/to/your/host/data:/usr/src/app/input \
    -v /absolute/path/to/your/host/output:/usr/src/app/output \
    -e OPERATION="deflate" \
    -e EXTENSION="tif" \
    -e NAME="manhattan" \
    geosolutionsit/nyc-doitt:1.0.0
```

- -v (Bind Mounts, `/absolute/path...`): Map your local input and output directories to the corresponding directories in the container.
- -e OPERATION: Specify the operation to perform: "deflate" or "compression". Defaults to "deflate".
- -e EXTENSION: The extension used to filter input files. Defaults to "jp2".
- -e NAME: Provides a name for your output files. Defaults to "output" if not specified.
  
> Note: The `--rm` option is included to automatically remove the container after the processing completes, helping to keep your Docker environment tidy. The `-t` option enables interactive mode, which can be helpful for viewing real-time logs and troubleshooting issues during execution. Feel free to adjust these options or the entire container run command to suit your specific needs and preferences.

## JPEG compression (lossy)

The "compression" operation uses a Shell script (`scripts/lossy_comp.sh`) that leverages the native GDAL implementation. This script converts input dataset files into TIFF format, employing JPEG compression with a lossless binary mask. It processes all input files within the specified folder and generates a single output TIFF file, named according to the `NAME` variable, in the designated output folder.

To ensure proper execution within a Docker container, the local input and output paths should be bound to the container paths `usr/src/app/input` and `usr/src/app/output`, respectively. This volume mapping still applies for deployment in cloud environments such as Kubernetes, where volumes for the input and output should be defined for the deployed container.

### Example

Let's assume the following paths for the processing of Brooklyn's aerial images:

- Input folder path: `/home/user/Desktop/JP2000` 
- Output folder path: `/home/user/Desktop/tiff_output`
  
To process the images, the command would be this:

```docker
docker run --rm \
    -v /home/user/Desktop/JP2000:/usr/src/app/input \
    -v /home/user/Desktop/tiff_output:/usr/src/app/output \
    -e OPERATION="compression" \
    -e EXTENSION="jp2" \
    -e NAME="brooklyn" \
    geosolutionsit/nyc-doitt:1.0.0
```

After the execution completes, the output is the single TIFF file `/home/user/Desktop/tiff_output/brooklyn.tif`:
```
/home/user/Desktop/tiff_output
├── brooklyn.tif
[...]
```

## COG with deflate compression (lossless)

The "deflate" operation utilizes the Python wrapper for the GDAL library, with the processing code located in `scripts/cog_deflate.py`. As input, the script expects the path to a folder containing the input files. The processed output chunks are then saved within the designated output folder, in a directory named according to the `NAME` variable.

The same considerations regarding the "compression" operation also apply in this case: the input and output paths should be bound to the container paths `usr/src/app/input` and `usr/src/app/output`, respectively. This should be done also for deployments in cloud environments, using volumes.

### Example

Let's assume this context for the processing of Manhattan's aerial images:

- Input folder path: `/home/user/Desktop/JP2000` 
- Output folder path: `/home/user/Desktop/processing_output`
  
The command would be the following:
```docker
docker run --rm -t \
    -v /home/user/Desktop/JP2000:/usr/src/app/input \
    -v /home/user/Desktop/processing_output:/usr/src/app/output \
    -e OPERATION="deflate" \
    -e EXTENSION="tif" \
    -e NAME="manhattan" \
    geosolutionsit/nyc-doitt:1.0.0
```

After the execution completes, the output chunks are going to be placed in a folder named "manhattan", inside the output directory `/home/user/Desktop/processing_output/manhattan`:
```
/home/user/Desktop/processing_output
├── manhattan
│   ├── chunk_0_0.tif
│   ├── chunk_0_131072.tif
│   ├── chunk_0_65536.tif
│   ├── chunk_65536_0.tif
│   [...]
[...]
```
## Additional information
- [Docker Hub repository](https://hub.docker.com/r/geosolutionsit/nyc-doitt)

## Changelog
- **1.0.0** 
  - First version
- **1.0.1**: 
  - Added the "extension" execution parameter to enable processing of different file types.
  - Automatic warp of rotated input images prior to the VRT creation.
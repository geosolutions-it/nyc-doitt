#!/bin/bash

input_folder="$1"

if [ ! -d "$input_folder" ]; then
    echo "Error: '$input_folder' is not a valid input directory."
    exit 1
fi

output_folder="$2"

if [ ! -d "$output_folder" ]; then
    echo "Error: '$output_folder' is not a valid output directory."
    exit 1
fi

result_folder="${output_folder}"

mkdir -p "$result_folder"

export GDAL_TIFF_INTERNAL_MASK=YES
export GDAL_CACHEMAX=20%
export CHECK_DISK_FREE_SPACE=FALSE

# Creating different versions of VRT
# One setting nodata to zero, to fill empty areas with zero needed to extract the binary mask
# One without any nodata filler (to work with SPARSE files. See below)
gdalbuildvrt "$result_folder"/group.vrt "$input_folder"/*.jp2 -vrtnodata "0 0 0 0"
gdalbuildvrt "$result_folder"/sparse.vrt "$input_folder"/*.jp2 -vrtnodata none
gdal_translate -CO TILED=YES -a_nodata none "$result_folder"/group.vrt "$result_folder"/group.tif

# Extracting the bands as separated VRTs, one for each band
gdal_translate -b 1 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b1.vrt
gdal_translate -b 2 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b2.vrt
gdal_translate -b 3 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b3.vrt
gdal_translate -b 4 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b4.vrt

# Computing the binary mask so that when a pixel is zero for all 4 bands, 
# the bitmask will be zero
gdal_calc.py --format GTIFF --type=Byte \
    --creation-option=PHOTOMETRIC=MINISBLACK \
    --creation-option=NBITS=1 \
    --creation-option=TILED=YES \
    --creation-option=COMPRESS=DEFLATE \
    -A "$result_folder"/group_b1.vrt \
    -B "$result_folder"/group_b2.vrt \
    -C "$result_folder"/group_b3.vrt \
    -D "$result_folder"/group_b4.vrt \
    --calc="logical_not(logical_and(logical_and(A==0,B==0),logical_and(C==0,D==0)))" \
    --overwrite \
    --outfile "$result_folder"/group.msk.tif


mv "$result_folder"/group.tif "$result_folder"/nosparse.tif

# Converting the VRT to a BigTIFF using sparse file (tiles coming from empty area won't be encoded) 
gdal_translate -CO TILED=YES -CO SPARSE_OK=TRUE -a_nodata none "$result_folder"/sparse.vrt "$result_folder"/group.tif

# Recomposing all pieces together: 3 bands + binary Mask
gdalbuildvrt -separate "$result_folder"/final.vrt "$result_folder"/group_b1.vrt "$result_folder"/group_b2.vrt "$result_folder"/group_b3.vrt "$result_folder"/group.msk.tif
gdal_translate -a_srs EPSG:6539 -CO "COMPRESS=JPEG" -CO "PHOTOMETRIC=YCBCR" -CO "TILED=YES" -CO BLOCKXSIZE=512 -CO BLOCKYSIZE=512 -b 1 -b 2 -b 3 -mask 4 "$result_folder"/final.vrt "$result_folder/${NAME}.tif"

# Adding overviews
gdaladdo -r average "$result_folder/${NAME}.tif" 2 4 8 16 32 64 128 256

find "$result_folder"/ -mindepth 1 -maxdepth 1 ! -name "*.tif" -type f -delete
rm -f "$result_folder/group.msk.tif" "$result_folder/group.tif" "$result_folder/nosparse.tif" 

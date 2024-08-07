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

listfile="$output_folder"/listfiles.txt
> $listfile

has_rotated_geotransform() {
    gdalinfo "$1" | grep -A 2 "GeoTransform ="
}


# Creating different versions of VRT
# One setting nodata to zero, to fill empty areas with zero needed to extract the binary mask
# One without any nodata filler (to work with SPARSE files. See below)

for file in "$input_folder"/*.${EXTENSION}; do
    base_name="${file%.*}"
    warped_file="${base_name}_warped.${EXTENSION}"

    # Check if the file has a rotated GeoTransform
    if [[ "$file" != *_warped.${EXTENSION} ]]; then
        if has_rotated_geotransform "$file"; then
            # If the file has a rotated GeoTransform, warp it and create a _warped file
            if [ ! -f "$warped_file" ]; then
                echo "$file has rotated geotransform. Warping it..."
                gdalwarp -tr 0.5 0.5 "$file" "$warped_file"
            fi
            echo "$warped_file" >> $listfile
        else
            # If the file doesn't have a rotated GeoTransform, add it directly to the list
            echo "$file" >> $listfile
        fi
    fi
done

gdalbuildvrt -input_file_list $listfile "$result_folder"/group.vrt -vrtnodata "0 0 0"
gdalbuildvrt -input_file_list $listfile "$result_folder"/sparse.vrt -vrtnodata none
gdal_translate -CO TILED=YES -a_nodata none "$result_folder"/group.vrt "$result_folder"/group.tif

# Extracting the bands as separated VRTs, one for each band
gdal_translate -b 1 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b1.vrt
gdal_translate -b 2 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b2.vrt
gdal_translate -b 3 -OF VRT "$result_folder"/group.tif "$result_folder"/group_b3.vrt

# Computing the binary mask so that when a pixel is zero for all 3 bands, 
# the bitmask will be zero
gdal_calc.py --format GTIFF --type=Byte \
    --creation-option=PHOTOMETRIC=MINISBLACK \
    --creation-option=NBITS=1 \
    --creation-option=TILED=YES \
    --creation-option=COMPRESS=DEFLATE \
    -A "$result_folder"/group_b1.vrt \
    -B "$result_folder"/group_b2.vrt \
    -C "$result_folder"/group_b3.vrt \
    --calc="logical_not(logical_and(logical_and(A==0,B==0),C==0))" \
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

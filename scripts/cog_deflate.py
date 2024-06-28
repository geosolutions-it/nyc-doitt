import os
import sys
import glob
import numpy as np
from osgeo import gdal
from concurrent.futures import ProcessPoolExecutor, as_completed


gdal.SetConfigOption('GDAL_CACHEMAX', '2048')
gdal.SetConfigOption('GDAL_NUM_THREADS', 'ALL_CPUS')
gdal.UseExceptions()


def create_vrt(input_files, vrt_path):
    print(f"Creating VRT with {len(input_files)} files...", flush=True)
    gdal.BuildVRT(vrt_path, input_files)
    print(f"VRT created: {vrt_path}", flush=True)


def get_vrt_size(vrt_path):
    vrt = gdal.Open(vrt_path)
    width = vrt.RasterXSize
    height = vrt.RasterYSize
    return width, height


def is_chunk_empty(vrt_path, x_offset, y_offset, x_size, y_size, output_file):
    vrt_options = gdal.TranslateOptions(
            format='GTIFF',
            srcWin=[x_offset, y_offset, x_size, y_size],
            width=check_size,
            height=check_size
        )
    sample = gdal.Translate(output_file, vrt_path, options=vrt_options)
    chunk = sample.ReadAsArray(0, 0, check_size, check_size)
    all_zero = np.all(chunk == 0)

    sample = None
    chunk = None
    os.remove(output_file)
    return all_zero


def process_chunk(vrt_path, x, y, x_size, y_size, output_file, resampling, ov_levels):
    if not is_chunk_empty(vrt_path, x, y, x_size, y_size, output_file):
        
        print("Starting single chunk processing...")

        gdal.Translate(
            output_file,
            vrt_path,
            outputSRS = 'EPSG:6539',
            srcWin=[x, y, x_size, y_size],
            format='COG',
            creationOptions=[
                'BIGTIFF=YES',
                'COMPRESS=DEFLATE', 
                f'RESAMPLING={resampling}',
                f'OVERVIEW_COUNT={ov_levels}',
                'OVERVIEWS=IGNORE_EXISTING',
                'SPARSE_OK=TRUE'
            ],
            bandList=[1, 2, 3],
            noData=0
        )

        print(f"Created chunk: {output_file}", flush=True)
    else:
        print(f"Skipped empty chunk at position ({x}, {y})", flush=True)


def process_vrt(vrt_path, chunk_size, output_dir, max_workers, resampling, ov_levels):
    width, height = get_vrt_size(vrt_path)
    
    print(f"Processing VRT of size {width}x{height} into chunks of size {chunk_size}x{chunk_size}...", flush=True)
    total_chunks = ((width + chunk_size - 1) // chunk_size) * ((height + chunk_size - 1) // chunk_size)
    chunk_counter = 0

    with ProcessPoolExecutor(max_workers=max_workers) as executor:
        futures = []
        for x in range(0, width, chunk_size):
            for y in range(0, height, chunk_size):
                x_size = min(chunk_size, width - x)
                y_size = min(chunk_size, height - y)
                output_file = os.path.join(output_dir, f'chunk_{x}_{y}.tif')
                futures.append(executor.submit(process_chunk, vrt_path, x, y, x_size, y_size, output_file, resampling,ov_levels))

        print(f"Need to process {len(futures)} chunks")
        
        for future in as_completed(futures):
            chunk_counter += 1
            print(f"Processed chunk {chunk_counter}/{total_chunks}", flush=True)
    
    print(f"Processing complete. Non-empty chunks saved in {output_dir}.", flush=True)


def main(input_dir, vrt_path, chunk_size, output_dir, max_workers, resampling, ov_levels):
    input_files = glob.glob(os.path.join(input_dir, '*.jp2'))
    if not input_files:
        print(f"No files found in the directory: {input_dir}", flush=True)
        return

    os.makedirs(output_dir, exist_ok=True)

    create_vrt(input_files, vrt_path)
    process_vrt(vrt_path, chunk_size, output_dir, max_workers, resampling, ov_levels)
    
    os.remove(vrt_path)


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python cog_deflate.py <input_directory> <output_directory>")
        sys.exit(1)


    input_dir = sys.argv[1]
    output_dir = f"{sys.argv[2]}/{os.environ.get('NAME')}"
    vrt_path = f"{output_dir}/output.vrt"
    chunk_size = 65536
    max_workers = 2
    resampling = 'bilinear'
    ov_levels = 8
    check_size = 1024
    main(input_dir, vrt_path, chunk_size, output_dir, max_workers, resampling, ov_levels)

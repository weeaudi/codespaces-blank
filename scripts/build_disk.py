#!/usr/bin/env python3
import sys
import os
import time
import math
import re
import parted
import sh
from pathlib import Path
from elftools.elf.elffile import ELFFile
from elftools.elf.descriptions import describe_p_type
from pyfatfs import PyFatFS

SECTOR_SIZE = 512

def generate_image_file(target: str, size_sectors: int):
    """Creates a zeroed-out 'target' file with size in sectors."""
    with open(target, 'wb') as f:
        f.write(bytes(size_sectors * SECTOR_SIZE))

def create_partition_table(target: str, align_start: int):
    """Use parted (Python bindings) to create a single, bootable partition."""
    device = parted.getDevice(target)
    disk = parted.freshDisk(device, 'msdos')
    free_space = disk.getFreeSpaceRegions()

    # Make a partition from align_start to the end of the free space.
    partition_geometry = parted.Geometry(device, start=align_start, end=free_space[-1].end)
    partition = parted.Partition(disk=disk,
                                 type=parted.PARTITION_NORMAL,
                                 geometry=partition_geometry)
    partition.setFlag(parted.PARTITION_BOOT)
    disk.addPartition(partition, constraint=device.optimalAlignedConstraint)
    disk.commit()

def create_filesystem(target: str, fs_type: str, partition_offset: int, reserved_sectors=0):
    """
    Creates a filesystem within 'target' at the given offset.
    Currently supports 'fat12', 'fat16', 'fat32', 'ext2'.
    For FAT, 'reserved_sectors' can be used for your stage2 space.
    """
    if fs_type.startswith('fat'):
        mkfs_fat = sh.Command('mkfs.fat')
        if fs_type == 'fat32':
            reserved_sectors += 1
        mkfs_fat(
            '-F', fs_type[3:],
            '-n', 'AIDOS',
            '-R', reserved_sectors,
            f'--offset={str(partition_offset)}',
            target
        )
    elif fs_type == 'ext2':
        mkfs_ext2 = sh.Command('mkfs.ext2')
        offset_bytes = partition_offset * SECTOR_SIZE
        mkfs_ext2(
            target,
            '-L', 'AIDOS',
            '-E', f'offset={offset_bytes}'
        )
    else:
        raise ValueError(f"Unsupported filesystem: {fs_type}")

def _find_symbol_in_map_file(map_file: Path, symbol: str):
    with map_file.open('r') as fmap:
        for line in fmap:
            if symbol in line:
                match = re.search(r'0x([0-9a-fA-F]+)', line)
                if match:
                    return int(match.group(1), base=16)
    return None


def install_stage1(target, stage1_bin, boot_data_lba, offset=0):
    """Write Stage1 into the target image at the correct offset, patching the relevant symbols."""
    map_file = Path(stage1_bin).with_suffix('.map')
    if not map_file.exists():
        raise FileNotFoundError(f"Missing map file for {stage1_bin}")

    phys = _find_symbol_in_map_file(map_file, 'phys')
    if phys is None:
        raise ValueError(f"Cannot find 'phys' in {map_file}")

    entry_offset = _find_symbol_in_map_file(map_file, '__entry_start')
    if entry_offset is None:
        raise ValueError(f"Cannot find '__entry_start' in {map_file}")
    entry_offset -= phys

    boot_data_lba_entry = _find_symbol_in_map_file(map_file, 'boot_data_lba')
    if boot_data_lba_entry is None:
        raise ValueError("Can't find 'boot_data_lba' symbol in map file " + str(map_file))
    boot_data_lba_entry -= phys

    with open(stage1_bin, 'rb') as fstage1:
        with os.fdopen(os.open(target, os.O_RDWR), 'r+b') as ftarget:
            # Seek to the partition offset (in sectors).
            ftarget.seek(offset * SECTOR_SIZE, os.SEEK_SET)

            # Write 3-byte jump instruction from Stage1
            ftarget.write(fstage1.read(3))

            # Write the rest of Stage1 from the entry_offset
            fstage1.seek(entry_offset - 3, os.SEEK_CUR)
            ftarget.seek(entry_offset - 3, os.SEEK_CUR)
            ftarget.write(fstage1.read())

            # Patch boot_data_lba in the image
            ftarget.seek(offset * SECTOR_SIZE + boot_data_lba_entry, os.SEEK_SET)
            ftarget.write(boot_data_lba.to_bytes(4, byteorder='little'))

def _addr_to_seg_offset(addr):
    seg = (addr & 0xFFFF0000) >> 4
    offset = addr & 0xFFFF
    return (seg << 16) | offset

def install_stage2(target, stage2_bin, boot_data_lba, offset=0, limit=0):
    """
    Writes stage2 ELF segments into 'target' at the given offset.
    Then writes a 'boot table' at boot_data_lba describing the segments.
    """
    with open(stage2_bin, 'rb') as fstage2:
        from elftools.elf.elffile import ELFFile

        with os.fdopen(os.open(target, os.O_RDWR), 'r+b') as ftarget:
            stage2_elf = ELFFile(fstage2)
            entry_point = _addr_to_seg_offset(stage2_elf.header['e_entry'])

            boot_table = []
            current_lba = offset

            # Read LOAD segments
            for segment in stage2_elf.iter_segments():
                if describe_p_type(segment['p_type']) == 'LOAD':
                    data = segment.data()
                    sectors = math.ceil(len(data) / SECTOR_SIZE)
                    load_addr = _addr_to_seg_offset(segment['p_paddr'])

                    boot_table.append({
                        'lba': current_lba,
                        'load_addr': load_addr,
                        'count': sectors
                    })

                    # Write the segment’s bytes into the image
                    ftarget.seek(current_lba * SECTOR_SIZE, os.SEEK_SET)
                    ftarget.write(data)

                    current_lba += sectors
                    if limit != 0 and current_lba >= limit:
                        raise Exception(f"Stage2 is too big for the image. Limit is {limit} sectors.")

            # Null terminator in the boot table
            boot_table.append({'lba':0, 'load_addr':0, 'count':0})

            # Write the boot table at boot_data_lba
            ftarget.seek(boot_data_lba * SECTOR_SIZE, os.SEEK_SET)
            # First 4 bytes = entry_point
            ftarget.write(entry_point.to_bytes(4, 'little'))
            # Then each segment entry
            for entry in boot_table:
                ftarget.write(entry['lba'].to_bytes(4, 'little'))
                ftarget.write(entry['load_addr'].to_bytes(4, 'little'))
                ftarget.write(entry['count'].to_bytes(2, 'little'))

def update_fat_filesystem(image_path: str, partition_offset: int, kernel_path: str, extra_files: list):
    """
    Update the FAT32 filesystem inside the disk image using PyFatFS in user space.
    This avoids the need for mounting via root or libguestfs. (MANY ISSUES WITH THOSE 2 T-T)
    It opens the disk image file at the partition offset, creates /boot (if missing),
    and copies the kernel and any extra files into the filesystem.
    """
    print(f"> Updating FAT32 filesystem in {image_path} at offset {partition_offset} sectors...")
    pf = PyFatFS.PyFatFS(filename=image_path, offset=partition_offset * SECTOR_SIZE)
    
    # Ensure the /boot directory exists.
    if not pf.exists("/boot"):
        print("  - Creating /boot directory")
        pf.makedir("/boot")
    
    # Copy the kernel file into /boot/kernel.elf.
    print(f"  - Copying kernel: {kernel_path} to /boot/kernel.elf")
    if not pf.exists("/boot/kernel.elf"):
        pf.create("/boot/kernel.elf")
    with open(kernel_path, 'rb') as kf:
        kernel_data = kf.read()
    with pf.open("/boot/kernel.elf", "wb") as dest:
        dest.write(kernel_data)
    
    # Process extra files (if any)
    for extra in extra_files:
        base = os.path.basename(extra)
        if os.path.isfile(extra):
            print(f"  - Copying extra file: {extra}")
            if not pf.exists("/" + base):
                pf.create("/" + base)
            with open(extra, 'rb') as ef:
                data = ef.read()
            with pf.open("/" + base, "wb") as dest:
                dest.write(data)
        elif os.path.isdir(extra):
            target_dir = "/" + base
            print(f"  - Creating directory for extra files: {target_dir}")
            try:
                pf.makedir(target_dir)
            except Exception:
                pass
            # Recursively copy directory contents.
            for root_dir, dirs, files in os.walk(extra):
                rel_path = os.path.relpath(root_dir, extra)
                if rel_path == ".":
                    current_target = target_dir
                else:
                    current_target = os.path.join(target_dir, rel_path).replace(os.sep, "/")
                    try:
                        pf.makedir(current_target)
                    except Exception:
                        pass
                for file in files:
                    local_file = os.path.join(root_dir, file)
                    target_file = os.path.join(current_target, file).replace(os.sep, "/")
                    print(f"    - Copying {local_file} to {target_file}")
                    if not pf.exists(target_file):
                        pf.create(target_file)
                    with open(local_file, 'rb') as lf:
                        data = lf.read()
                    with pf.open(target_file, "wb") as dest:
                        dest.write(data)
    
    pf.close()  # Ensure changes are written back.
    print("> FAT32 filesystem update complete.")

def build_disk(image_path, stage1_bin, stage2_bin, kernel_path, size_bytes, fs_type, extra_files=None):
    """
    Main function to:
      1. Create a disk image file of size_bytes
      2. Create an MBR partition table
      3. Format partition with fs_type
      4. Install Stage1/Stage2 bootloaders
      5. Update the FAT32 filesystem with the kernel and extra files
    """
    partition_offset = 2048  # commonly 1MB = 2048 sectors if SECTOR_SIZE=512
    stage2_sectors = math.ceil(os.stat(stage2_bin).st_size / SECTOR_SIZE)

    # 1) Create the empty image.
    size_sectors = math.ceil(size_bytes / SECTOR_SIZE)
    generate_image_file(image_path, size_sectors)

    # 2) Create the partition table.
    print("> Creating partition table...")
    create_partition_table(image_path, partition_offset)

    # 3) Format the partition.
    print(f"> Formatting with {fs_type} at offset={partition_offset}...")
    create_filesystem(image_path, fs_type, partition_offset, reserved_sectors=stage2_sectors)

    # 4) Install Stage1 & Stage2 bootloaders.
    print("> Installing Stage1...")
    install_stage1(image_path, stage1_bin, boot_data_lba=1, offset=partition_offset)

    print("> Installing Stage2...")
    install_stage2(image_path, stage2_bin, boot_data_lba=1, offset=2, limit=partition_offset-2)

    # 5) Install kernel and extra files
    if fs_type.lower() in ['fat12', 'fat16', 'fat32']:
        print("> Updating FAT32 filesystem with kernel and extra files...")
        update_fat_filesystem(image_path, partition_offset, kernel_path, extra_files if extra_files else [])
    else:
        print("> Filesystem type is not FAT; skipping filesystem update.")

    print("> Done Generating Disk")

def main():
    """
    Usage: build_disk.py <image_path> <stage1_bin> <stage2_bin> <kernel> <size_bytes> <fs_type> [extra_files...]
    Example:
        python3 build_disk.py disk_image.raw stage1.bin stage2.elf kernel.elf 33554432 fat32 file1.txt dir2 ...
    """
    if len(sys.argv) < 7:
        print("Usage: build_disk.py <image_path> <stage1_bin> <stage2_bin> <kernel> <size_bytes> <fs_type> [extra_files...]")
        sys.exit(1)

    image_path   = sys.argv[1]
    stage1_bin   = sys.argv[2]
    stage2_bin   = sys.argv[3]
    kernel_path  = sys.argv[4]
    size_bytes   = int(sys.argv[5])
    fs_type      = sys.argv[6]
    extra_files  = sys.argv[7:] if len(sys.argv) > 7 else []

    build_disk(
        image_path=image_path,
        stage1_bin=stage1_bin,
        stage2_bin=stage2_bin,
        kernel_path=kernel_path,
        size_bytes=size_bytes,
        fs_type=fs_type,
        extra_files=extra_files
    )
    print("Disk image creation complete!")

if __name__ == "__main__":
    main()

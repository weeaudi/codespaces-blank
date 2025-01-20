Small os project.

setup

run apt_installer.sh as root to install dependancies (ubuntu) or find packages in file and manually install them (other os'es)

download asm4doxy.pl from https://github.com/rfoos/doxygen and put it into scripts/

building

    mkdir <build_dir>
    cd <build_dir>
    cmake ..
    cmake --build .

this will automatically download and build gcc and binutils for you.

to run

    (in build directory)
    cmake --build . --target=run

    or

    qemu-system-i386 -fda <build_dir>/out/floppy-<aidos_project_version>.img

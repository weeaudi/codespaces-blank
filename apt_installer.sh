apt update
apt install libmpc-dev libgmp-dev cmake texinfo yasm qemu-system-x86-64 python3-parted libguestfs-tools doxygen python3-parted libparted-dev -y
pip3 install pyparted sh pyelftools
chmod +r /boot/vmlinuz-*
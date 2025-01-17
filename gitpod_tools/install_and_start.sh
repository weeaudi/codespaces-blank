sudo apt update
sudo apt install ubuntu-gnome-desktop tightvncserver xfce4 xfce4-goodies -y
vncserver
vncserver -kill :1
echo "startxfce4" >> ~/.vnc/xstartup
vncserver
./novnc/utils/novnc_proxy --vnc 0.0.0.0:5901
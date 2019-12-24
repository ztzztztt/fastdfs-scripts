#!/bin/bash

#yum install -y wget

yum install -y git gcc gcc-c++ make automake autoconf libtool pcre pcre-devel zlib zlib-devel openssl-devel

mkdir fastdfs
echo "entry directory: fastdfs"
cd fastdfs
if [ ! -f "fastdfs_6.04.tar.gz" ]; then
    echo "Downloading FastDFS-V6.04.tar.gz"
    wget https://github.com/happyfish100/fastdfs/archive/V6.04.tar.gz -O fastdfs_6.04.tar.gz
fi
if [ ! -f 'libfastcommon_1.0.42.tar.gz' ]; then
    echo "Downloading LibFastCommon-V1.0.42.tar.gz"
    wget https://github.com/happyfish100/libfastcommon/archive/V1.0.42.tar.gz -O libfastcommon_1.0.42.tar.gz
fi
if [ ! -f "fastdfs-nginx-module_1.22.tar.gz" ]; then
    echo "Downloading FastDFS-Nginx_Module-V1.22.tar.gz"
    wget https://github.com/happyfish100/fastdfs-nginx-module/archive/V1.22.tar.gz -O fastdfs-nginx-module_1.22.tar.gz
fi
if [ ! -f "nginx-1.17.6.tar.gz" ]; then
    echo "Downloading Nginx-1.17.6.tar.gz"
    wget http://nginx.org/download/nginx-1.17.6.tar.gz -O nginx-1.17.6.tar.gz
fi

tar -xzvf libfastcommon_1.0.42.tar.gz
cd libfastcommon-1.0.42
bash make.sh && bash make.sh install
cd ..

tar -xzvf fastdfs_6.04.tar.gz
cd fastdfs-6.04
bash make.sh && bash make.sh install
cp /etc/fdfs/tracker.conf.sample /etc/fdfs/tracker.conf
cp /etc/fdfs/storage.conf.sample /etc/fdfs/storage.conf
cp /etc/fdfs/client.conf.sample /etc/fdfs/client.conf
cp ./conf/http.conf /etc/fdfs/
cp ./conf/mime.types /etc/fdfs/
cd ..


tar -xzvf fastdfs-nginx-module_1.22.tar.gz
cp ./fastdfs-nginx-module-1.22/src/mod_fastdfs.conf /etc/fdfs

tar -xzvf nginx-1.17.6.tar.gz
cd nginx-1.17.6
./configure --add-module=../fastdfs-nginx-module-1.22/src/
make && make install
cd .. && cd ..

rm -rf fastdfs

echo "please modify tracker.conf, type the follow command to modify"
echo "vim /etc/fdfs/tracker.conf"
echo "port=22122"
echo "mkdir -p /data/fastdfs/"
echo "base_path=/data/fastdfs/"

echo "please modify storage.conf, type the follow command to modify"
echo "vim /etc/fdfs/storage.conf"
echo "port=23000"
echo "base_path=/data/fastdfs/"
echo "store_path0=/data/fastdfs/"
echo "tracker_server=Your IP:22122"
echo "http.server_port=8888"

echo "if you finish above,please type the follow command to start"
echo "/etc/init.d/fdfs_trackerd start"
echo "chkconfig fdfs_trackerd on"

echo "/etc/init.d/fdfs_storaged start"
echo "chkconfig fdfs_storaged on"

# configure tracker
mkdir -p /data/fastdfs
echo "base_path=/data/fastdfs/" > /etc/fdfs/tracker.conf

# configure storage
echo "base_path=/data/fastdfs/" > /etc/fdfs/storage.conf
echo "store_path0=/data/fastdfs/" > /etc/fdfs/storage.conf
ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
echo "tracker_server=$ip:22122" > /etc/fdfs/storage.conf
chkconfig fdfs_trackerd on
chkconfig fdfs_storaged on
/etc/init.d/fdfs_trackerd start
/etc/init.d/fdfs_storaged start

# configure nginx
echo "tracker_server=$ip:22122" > /etc/fdfs/mod_fastdfs.conf
echo "url_have_group_name=true" > /etc/fdfs/mod_fastdfs.conf
echo "store_path0=/data/fastdfs" > /etc/fdfs/mod_fastdfs.conf

echo "server {
    listen       8888;
    server_name  localhost;
    location ~/group[0-9]/ {
        ngx_fastdfs_module;
    }
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
    root   html;
    }
}" > nginx_modify.txt
sed -i "34r nginx_modify.txt" /usr/local/nginx/conf/nginx.conf

rm -rf nginx_modify.txt

echo "[Unit]
Description=nginx
After=network.target
[Service]
Type=forking
ExecStart=/usr/local/nginx/sbin/nginx
ExecReload=/usr/local/nginx/sbin/nginx reload
ExecStop=/usr/local/nginx/sbin/nginx quit
PrivateTmp=true
[Install]
WantedBy=multi-user.target" > /lib/systemd/system/nginx.service

systemctl enable nginx.service
systemctl start nginx



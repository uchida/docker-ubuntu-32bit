#!/bin/bash -ex
### Build a docker image for ubuntu i386.

### settings
arch=i386
suite=trusty
chroot_dir="/var/chroot/$suite"
apt_mirror='http://archive.ubuntu.com/ubuntu'
docker_image="auchida/ubuntu-32bit:$suite"

### make sure that the required tools are installed
apt-get install -y docker.io debootstrap dchroot

### install a minbase system with debootstrap
export DEBIAN_FRONTEND=noninteractive
debootstrap --variant=minbase --arch=$arch $suite $chroot_dir $apt_mirror

### update the list of package sources
cat <<EOF > $chroot_dir/etc/apt/sources.list
deb $apt_mirror $suite main restricted
deb-src $apt_mirror $suite main restricted

deb $apt_mirror $suite-updates main restricted
deb-src $apt_mirror $suite-updates main restricted

deb http://archive.ubuntu.com/ubuntu/ $suite universe
EOF

### install ubuntu-minimal
cp /etc/resolv.conf $chroot_dir/etc/resolv.conf
mount -o bind /proc $chroot_dir/proc
chroot $chroot_dir apt-get update
chroot $chroot_dir apt-get -y install ubuntu-minimal

### workaround, http://github.com/docker/docker/issues/1024
chroot $chroot_dir dpkg-divert --local --rename --add /sbin/initctl
chroot $chroot_dir ln -sf /bin/true /sbin/initctl

### workaround, to skip failure to update libpam-systemd
chroot $chroot_dir ln -sf /bin/true /etc/init.d/systemd-logind

### cleanup and unmount /proc
chroot $chroot_dir apt-get autoclean
chroot $chroot_dir apt-get clean
chroot $chroot_dir apt-get autoremove
rm $chroot_dir/etc/resolv.conf
umount $chroot_dir/proc

### cleanup
find $chroot_dir/var/cache -type f -delete
find $chroot_dir/var/lib/apt/lists -type f -delete

### create a tar archive from the chroot directory
tar cfz ubuntu.tgz -C $chroot_dir .

### import this tar archive into a docker image:
cat ubuntu.tgz | docker import - $docker_image

# ### push image to Docker Hub
# docker push $docker_image

# ### cleanup
# rm ubuntu.tgz
# rm -rf $chroot_dir

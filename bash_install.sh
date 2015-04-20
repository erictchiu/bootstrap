#!/bin/bash
# (c) 2015, by Wasiliy Besedin, besco@yabesco.ru, 2:5028/68@fidonet.org, skype: unique-login-for-all

isoUrl="http://mirror.corbina.net/pub/Linux/centos/7/isos/x86_64/CentOS-7-x86_64-Minimal-1503-01.iso";
tftp_root="/tftpboot";
isoFile="";

function installSoft {
    # The necessary software
    nSoft=("dhcp" "httpd" "syslinux" "tftp" "tftp-server" "vim-enhanced" "wget" "nfs-utils");

    for index in ${!nSoft[*]}
    do
        checkInstall=`yum list installed "${nSoft[$index]}" &>/dev/null`;
        if [ $? == "1" ]; then 
	    echo "${nSoft[$index]} is not installed. Installing...";
	    rc=`yum install -y ${nSoft[$index]}`;
	    if [ $? == "1" ]; then 
		echo "Install ${nSoft[$index]} failed:";
		echo $rc;
	    else
		echo "Install ${nSoft[$index]} complete.";
	    fi
        else 
    	    echo "${nSoft[$index]} ready."
        fi
    done
}

function GiveMeBackMyEth {
    status=0;
    echo "Checking for changes in system for names of the interfaces";
    result=`cat /etc/sysconfig/grub | grep net.ifnames | wc -l`;
    if [ $result -eq "0" ]; then
	echo "Changes not detected. Check interfaces names";
	result=`ifconfig|grep eth0 | wc -l`;
	if [ $result -eq "0" ]; then
	    echo "Not found eth! Correcting."
	    ruselt=`sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 /' /etc/sysconfig/grub`;
	fi
    fi
}

function createDhcpConf {
    echo "Creating config for DHCP server";
    echo "";
    eth_arr=(`ifconfig|grep flags|awk '{split ($1,a,":"); print a[1]}'|xargs`)
    echo "On what interface DHCP must listen to?";
    echo "Fount ${#eth_arr[@]} interfaces.";
    for index in ${!eth_arr[*]}    
    do
	echo "["$index"] "${eth_arr[$index]}
    done
    echo -n "On what interface DHCP must listen to? [1]: ";
    read int_num
    if [ !$int_num ]; then
	int_num=1;
    fi
    int_ip=`ifconfig ${eth_arr[$int_num]} |grep -w inet|awk '{print $2}'`
    echo "You select ${eth_arr[$int_num]}. Good choice :)";

    echo -n "Enter PXE server ip [$int_ip]: "
    read server_ip
    if [ !$server_ip ]; then
	server_ip=$int_ip
    fi
    network=`echo $server_ip|awk '{split($1,a,"."); print a[1]"."a[2]"."a[3]".0"}'`;
    echo -n "Enter netmask [255.255.255.0]: "
    read netmask_nm;
    if [ !$netmask_nm ]; then
	netmask_nm="255.255.255.0"
    fi

    echo -n "Enter network domain [localdomain]: "
    read network_dn
    if [ !$network_dn ]; then 
	network_dn="localdomain"
    fi
    
    echo -n "Enter DNS ip[$server_ip]: "
    read dns_ip
    if [ !$dns_ip ]; then
	dns_ip=$server_ip
    fi    
    
    echo -n "Enter gateway ip [$server_ip]: "
    read gateway_ip
    if [ !$gateway_ip ]; then
	gateway_ip=$server_ip
    fi
    auto_first_ip=`echo $server_ip|awk '{split($1,a,"."); print a[1]"."a[2]"."a[3]".10"}'`;
    
    echo -n "Enter first ip of range [$auto_first_ip]: "
    read first_ip
    if [ !$first_ip ]; then
	first_ip=$auto_first_ip
    fi
    auto_last_ip=`echo $server_ip|awk '{split($1,a,"."); print a[1]"."a[2]"."a[3]".100"}'`;
    
    echo -n "Enter last ip of range [$auto_last_ip]: "
    read last_ip
    if [ !$last_ip ]; then

	last_ip=$auto_last_ip
    fi
    
    echo -n "Enter tftp server [$server_ip]: "
    read tftpd_ip
    if [ !tftpd_ip ]; then
	tftpd_ip=$server_ip
    fi

    backup_ext=`date +%m-%d-%Y" "%H:%M:%S`;
    rc=`cp /etc/dhcp/dhcpd.conf "/etc/dhcp/dhcpd.conf-$backup_ext"`;

cat > /etc/dhcp/dhcpd.conf << EOF
option option-100 code 100 = string;
option option-128 code 128 = string;
option option-129 code 129 = text;
option option-140 code 140 = string;
option option-141 code 141 = unsigned integer 32;
option option-142 code 142 = string;
option option-143 code 143 = string;
option option-144 code 144 = string;
option option-144 "n";
option option-140 "$server_ip";

# ddns-update-style ad-hoc;
log-facility syslog;

option domain-name "$network_dn";
option domain-name-servers $dns_ip;
option subnet-mask $netmask_nm;
subnet $network netmask $netmask_nm {
    authoritative;
    range $first_ip $last_ip;
    option routers $gateway_ip;
    allow booting;
    allow bootp;
    next-server $tftpd_ip;
    filename "pxelinux.0";
}
EOF
    `systemctl restart dhcpd`
    echo "DHCP configuration complete.";
    echo "$tftp_root $network/255.255.255.0(ro)" >>/etc/exports
}

function createTftp {
    echo "Setting up TFTP server and prepare tftproot directory";
    echo "";


    
    backup_ext=`date +%m-%d-%Y" "%H:%M:%S`;
    rc=`cp /etc/xinetd.d/tftp "/etc/xinetd.d/tftp-$backup_ext"`;

    echo "Creating TFTP config"
cat > /etc/xinetd.d/tftp << EOF
service tftp
{
	socket_type		= dgram
	protocol		= udp
	wait			= yes
	user			= root
	server			= /usr/sbin/in.tftpd
	server_args		= -s $tftp_root
	disable			= no
	per_source		= 11
	cps			= 100 2
	flags			= IPv4
}
EOF

    echo "Creating $tftp_root";
    mkdir -p $tftp_root
    chmod 777 $tftp_root
    
    echo "Preparing directory";
    cp /usr/share/syslinux/{pxelinux.0,menu.c32,memdisk,mboot.c32,chain.c32} $tftp_root
#    cp /usr/share/syslinux/menu.c32 $tftp_root
#    cp /usr/share/syslinux/memdisk $tftp_root
#    cp /usr/share/syslinux/mboot.c32 $tftp_root
#    cp /usr/share/syslinux/chain.c32 $tftp_root
  
    echo "Preparing PXE files"
    mkdir $tftp_root/pxelinux.cfg
    mkdir -p $tftp_root/netboot/centos/7/x86_64
    
    echo "Downloading initrd.img"
    wget -q --directory-prefix=$tftp_root/netboot/centos/7/x86_64 -c ftp://ftp.ines.lug.ro/centos/7/os/x86_64/images/pxeboot/initrd.img
    echo "Downloading vmlinuz"
    wget -q --directory-prefix=$tftp_root/netboot/centos/7/x86_64 -c ftp://ftp.ines.lug.ro/centos/7/os/x86_64/images/pxeboot/vmlinuz
    systemctl restart xinetd
    echo "Preparing TFTP complete"
};

function disableSelinux {
    echo "Disabling SElinux";
    status=`cat /etc/selinux/config |grep -w SELINUX|grep -v "#"|awk '{split($1,a,"=");print a[2]}'| tr [a-z] [A-Z]`
    if [ "$status" == "DISABLED" ]; then
	echo "SElinux already disabled"
    else
	`sed -i 's/=enforcing/=disabled/;s/=permissive/=disabled/' /etc/selinux/config`;
	echo "SElinux disabled. You must reboot server"
    fi
};

function disableFirewalld {
    echo "Disabling firewalld"
    systemctl disable firewalld
    systemctl stop firewalld
};

function prepareNetwork {
    echo "Preparing network"
    disableSelinux;
    disableFirewalld;
    netArray=("net.ipv4.ip_forward=1")
    for index in ${!netArray[*]}
    do
	rc=`cat /etc/sysctl.conf |grep ${netArray[$index]}|wc -l`
	if [ $rc -eq 0 ]; then
	    echo "Add ${netArray[$index]} in sysctl"
	    echo "${netArray[$index]}" >> /etc/sysctl.conf
	else
	    echo "${netArray[$index]} already exist"
	fi
    done
};

function prepareImage {
    echo "Preparing installation image."
    echo ""
    if [ !$isoFile ]; then 
	echo -n "Donwload Centos 7 image from $isoUrl? (YN)[N]: "
	read yn
	if [[ $yn == "Y" || $yn == "y" ]]; then 
	    #wget -c --directory-prefix=/tmp $isoUrl
	    `echo "$isoUrl"|awk '{n=split(\$1,a,"/");print a[n]}'`
	    isoFile="/tmp/`echo "$isoUrl"|awk '{n=split(\$1,a,"/");print a[n]}'`"; 
	fi
    fi
    if [ $isoFile ]; then
	echo "Mounting $isoFile to /mnt"
	mount -o loop $isoFile /mnt
	rc=$?
	if [ $rc -eq "0" ]; then
	    echo "Mount succesful";
	    mkdir $tftp_root/centos
	    cp -fvr /mnt/* $tftp_root/centos/
	    umount /mnt
	    echo "Preparing complete";
	else
	    echo "Mount failed. Errcode = $rc"; 
	fi
    fi
    
    # Mount errcodes:
    # 0      success
    # 1      incorrect invocation or permissions
    # 2      system error (out of memory, cannot fork, no more loop devices)
    # 4      internal mount bug
    # 8      user interrupt
    # 16     problems writing or locking /etc/mtab
    # 32     mount failure
    # 64     some mount succeeded
};

while test $# -gt 0
do
    case $1 in
        --isourl)
            isoUrl=$2
            shift
            ;;
        --isofile)
    	    isoFile=$2
    	    shift
    	    ;;
        --prepareSoft)
            installSoft	
            shift
            ;;
        --prepareDhcp)
            createDhcpConf
            shift
            ;;
        --prepareTftp)
    	    createTftp
    	    shift
    	    ;;
    	--prepareNetwork)
    	    prepareNetwork
    	    shift
    	    ;;
    	--prepareImage)
    	    prepareImage
    	    shift
    	    ;;
        *)
            echo >&2 "Invalid argument: $1"
            ;;
    esac
    shift
done


#!/bin/bash


function installSoft {
    # The necessary software
    nSoft=("dhcp" "httpd" "syslinux" "tftp" "tftp-server" "vim-enhanced" "wget");

    for index in ${!nSoft[*]}
    do
        checkInstall=`yum list installed "${nSoft[$index]}" &>/dev/null`;
        if [ $? == "1" ]; then 
	    echo "${nSoft[$index]} is not installed. Installing:";
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

    #ifconfig|grep flags|awk '{split ($1,a,":"); print a[1]}'

    echo "Enter settings for DHCP server";
    echo "Enter PXE server ip:"
    read server_ip
    network=`echo $server_ip|awk '{split($1,a,"."); print a[1]"."a[2]"."a[3]".0"}'`;
    echo "Enter netmask (255.255.255.0):"
    read netmask_nm;
    if [ !$netmask_nm ]; then
	netmask_nm="255.255.255.0"
    fi
    echo "Enter network domain:"
    read network_dn
    echo "Enter DNS ip($server_ip):"
    read dns_ip
    if [ !$dns_ip ]; then
	dns_ip=$server_ip
    fi    
    echo "Enter gateway ip($server_ip):"
    read gateway_ip
    if [ !$gateway_ip ]; then
	gateway_ip=$server_ip
    fi
    auto_first_ip=`echo $server_ip|awk '{split($1,a,"."); print a[1]"."a[2]"."a[3]".10"}'`;
    echo "Enter first ip of range ($auto_first_ip):"
    read first_ip
    if [ !$first_ip ]; then
	first_ip=$auto_first_ip
    fi
    auto_last_ip=`echo $server_ip|awk '{split($1,a,"."); print a[1]"."a[2]"."a[3]".100"}'`;
    echo "Enter last ip of range ($auto_last_ip):"
    read last_ip
    if [ !$last_ip ]; then
	last_ip=$auto_last_ip
    fi
    echo "Enter tftp server ($server_ip):"
    read tftpd_ip
    if [ !tftpd_ip ]; then
	tftpd_ip=$server_ip
    fi
    backup_ext=`date +%m-%d-%Y" "%H:%M:%S`;
    rc=`cp /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf-$backup_ext`;
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

ddns-update-style ad-hoc;
log-facility syslog;

option domain-name "$network_dn";
option domain-name-servers $dns_ip;
option subnet-mask $network_nm;
subnet $network netmask $network_nm {
    authoritative;
    range $first_ip $last_ip;
    option routers $gateway_ip;
    allow booting;
    allow bootp;
    next-server $tftpd_ip;
    filename "pxelinux.0";
}
EOF


}
# GiveMeBackMyEth
# installSoft;
createDhcpConf

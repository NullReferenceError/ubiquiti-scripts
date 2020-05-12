#!/bin/vbash
# This script should be copied into:
# /etc/ppp/ip-up.d/enable-ipv6-6rd.sh for Ubiquiti USG (On the actual gateway)
# /config/scripts/post-config.d/enable-ipv6-6rd.sh if you want the script to run after reboots
# /config/scripts/ppp/ip-up.d/enable-ipv6-6rd.sh for Ubiquiti Edgerouter (needs confirmation)
#
#
# This script is an aggregation of data taken from:
# https://github.com/cpcowart/ubiquiti-scripts
# https://gist.github.com/larstobi/a9e0aecf3ed0cc3c452139bf123140d3
# https://sosdg.org/edgerouter/6rd
# https://community.ubnt.com/t5/EdgeMAX/Edgerouter-Lite-on-Centurylink-1-Gbit-fiber/td-p/1124318/page/2
# 

# These may differ in your environment
# TODO: switch these to params
export DESCRIPTION="IPv6 6rd tunnel"
export WAN_DEV="pppoe2"
export LAN_DEV="eth1"
export TUN_DEV="tun0"
export CLEAN_CONFIG=true
export DEBUG=true

# These settings are specific to your ISP (CenturyLink shown)
export IP6_6RD_PREFIX="2602"
export IP6_6RD_PREFIX_LEN="24"
# This is an IP6 gateway tunnel bridge switch for centurylink
export IP6_6RD_ROUTER="205.171.2.64"
# This is used in calculating the prefix length of the WAN_6 address. (Centurylink Residential is typically 64, Business is 56)
export WAN_6_PREFIX_LEN="64"

# IPv6 supported DNS nameservers (Only need one of these enabled)
#CenturyLink/qwest 
export IP6_NAMESERVERS="2001:428::1 2001:428::2"
#Cloudflare DNS: 							
#export IP6_NAMESERVERS="2606:4700:4700::1111 2606:4700:4700::1001"
#Google DNS:
#export IP6_NAMESERVERS="2001:4860:4860::8888 2001:4860:4860::8844"
#OpenDNS:
#export IP6_NAMESERVERS="2620:0:ccc::2 2620:0:ccd::2"

# You probably shouldn't touch these
export SBIN="/opt/vyatta/sbin/my_"
export TUN_STATUS=""
export WAN_4_ADDR=""
export WAN_6_OLD=""
export WAN_6_NEW=""


# get_ip4() will pull the current IPv4 address from ipv4 addr for a specific device
# param $1 - The device to grab the address for
get_ip4()
{
    IP4=$(ip -4 -o addr list "$1" | awk '{print $4}' | cut -d/ -f1)

    # If this doesn't resolve, then try getting it from some public IP service (ala ipify.org, )
    if [ -z "$IP4" ]; then
        echo "Unable to determine IPv4 address"
        exit 2
    fi

    echo "$IP4"
}

# get_ip6 will pull an IPv6 address from the specified device interface
# global $IP6_6RD_Prefix - the configured IP6 global prefix
# param $1 - The device to grab the address for
get_ip6()
{
    ip -6 -o addr show up "$1" | \
        grep $IP6_6RD_PREFIX | grep -v fe80 | \
        awk '{print $4}' | cut -f1 -d/ | head -n1
}

# get_derived_ip6 will pass an IP4 address in and determine the 6rd address conversion 
# global $IP6_6RD_Prefix - the configured IP6 global prefix
# param $1 - An IP4 Address
get_derived_ip6()
{
    printf "$IP6_6RD_PREFIX:%02x:%02x%02x:%02x00::1\n" $(echo "$1" | tr . ' ')
}


# apply_config will apply the current configuration to a vyatta supported device
# global $TUN_STATUS - The tunnel interface status
# global $SBIN - The Vyatta sbin/my_* location
# global $TUN_DEV - The device to configure as the tunnel
# global $DESCRIPTION - The description to give the tunnel
# global $IP6_6RD_Prefix - The IPv6 Prefix from the ISP
# global $IP6_6RD_PREFIX_LEN - The IPv6 Prefix Length from the ISP
# global $IP6_6RD_ROUTER - An IPv6 6rd tunnel bridge from the ISP
# global $WAN_4_ADDR - The public IPv4 address for the configured device
# global $LAN_DEV - The configured LAN device interface
# global $WAN_6_NEW - The derived IPv6 address based on the WAN address
# global $WAN_6_PREFIX_LEN - The Derived IPv6 address's prefix
# global $IP6_NAMESERVERS - Any configured IPv6 DNS nameservers to configure the interface with
apply_config()
{
    if [ -n "$TUN_STATUS" ]; then
        # delete the existing tunnel interface
        ${SBIN}delete interfaces tunnel $TUN_DEV
    fi
    # Configure the $TUN_DEV device
    # older firmwares of edgerouter may need to set a static route with the following line:
    # ${SBIN}set protocols static route6 '::/0' next-hop "::${IP6_6RD_ROUTER}" interface $TUN_DEV
    ${SBIN}set interfaces tunnel $TUN_DEV 6rd-default-gw "::${IP6_6RD_ROUTER}"
    ${SBIN}set interfaces tunnel $TUN_DEV description "$DESCRIPTION"
    ${SBIN}set interfaces tunnel $TUN_DEV 6rd-prefix "${IP6_6RD_PREFIX}::/${IP6_6RD_PREFIX_LEN}"
    ${SBIN}set interfaces tunnel $TUN_DEV encapsulation sit
    ${SBIN}set interfaces tunnel $TUN_DEV ttl 255
    ${SBIN}set interfaces tunnel $TUN_DEV mtu 1472
    ${SBIN}set interfaces tunnel $TUN_DEV firewall in ipv6-name WANv6_IN
    ${SBIN}set interfaces tunnel $TUN_DEV firewall local ipv6-name WANv6_LOCAL
    ${SBIN}set interfaces tunnel $TUN_DEV firewall out ipv6-name WANv6_OUT    
    # older guides do not have remote-ip and local-ip configured
    # Commenting this out as it seems to conflict
    #${SBIN}set interfaces tunnel $TUN_DEV remote-ip "$IP6_6RD_ROUTER"
    ${SBIN}set interfaces tunnel $TUN_DEV local-ip "$WAN_4_ADDR"
    # another guide has multicast enabled
    ${SBIN}set interfaces tunnel $TUN_DEV multicast disable

    # Configure the $LAN_DEV device
    ${SBIN}set interfaces ethernet $LAN_DEV address ${WAN_6_NEW}/${WAN_6_PREFIX_LEN}
    ${SBIN}delete interfaces ethernet $LAN_DEV ipv6
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 dup-addr-detect-transmits 1
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert cur-hop-limit 64
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert managed-flag false
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert max-interval 300
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert link-mtu 0
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert other-config-flag false
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert prefix "${WAN_6_NEW}/${WAN_6_PREFIX_LEN}" autonomous-flag true
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert prefix "${WAN_6_NEW}/${WAN_6_PREFIX_LEN}" on-link-flag true
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert prefix "${WAN_6_NEW}/${WAN_6_PREFIX_LEN}" valid-lifetime 3600
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert reachable-time 0
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert retrans-timer 0
    ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert send-advert true

    #Loop nameservers and add them into the router-advert config
    for ns in $IP6_NAMESERVERS;
    do
        ${SBIN}set interfaces ethernet $LAN_DEV ipv6 router-advert name-server "$ns"
    done
}

# Remove config will backout any changes made my the script
# global $SBIN - The Vyatta sbin/my_* location
# global $TUN_DEV - The device to configure as the tunnel that we want to delete
# global $LAN_DEV - The configured LAN device interface that we want to remove the IPv6 config from
clean_config() 
{
    # Delete the configured tunnel
    ${SBIN}delete interfaces tunnel $TUN_DEV
    # Delete the IPv6 config from the $LAN_DEV
    ${SBIN}delete interfaces ethernet $LAN_DEV ipv6
    # Delete the IPv6/prefix address if its configured
    WAN_6_LAN=$(get_ip6 "$LAN_DEV")
    if [ -n "$WAN_6_LAN" ]; then
        ${SBIN}delete interfaces ethernet $LAN_DEV address $WAN_6_LAN/${WAN_6_PREFIX_LEN}
    fi
} 

#################################################
##### Main script functionality starts here #####
#################################################

# If the debug switch was passed, be more verbose
if [ -n $DEBUG ]; then
    set -x
fi

if [ -n "$PPP_IFACE" ] && [ -n "$PPP_LOCAL" ]; then
    # called by ppp-up script Does this matter?
    # WAN_DEV=""
    echo "Script called from pppoe up script"
    WAN_4_ADDR=$(get_ip4 "$WAN_DEV")
    echo "PPP script: Found public IPv4 $WAN_4_ADDR on $WAN_DEV"
else
    WAN_4_ADDR=$(get_ip4 "$WAN_DEV")
    echo "Found public IPv4 $WAN_4_ADDR on $WAN_DEV"
fi

# Source the script template for vyatta commands
source /opt/vyatta/etc/functions/script-template
configure

#If clean is true, remove any existing configs
if [ -n $CLEAN_CONFIG ]; then
    echo "Cleaning old configs..."
    clean_config && commit && save
fi

echo "Getting tunnel status..."

# Get tunnel status from device
TUN_STATUS=$(show interfaces tunnel "$TUN_DEV")

echo "Determining IPv6 WAN address for $WAN_4_ADDR..."

# Derive new wan address from public IP
WAN_6_NEW=$(get_derived_ip6 "$WAN_4_ADDR")

echo "IPv6 Address is $WAN_6_NEW"

# If the tunnel exists, lets check the IPv6 Address
if [ -n "$TUN_STATUS" ]; then

    WAN_6_OLD=$(get_ip6 "$LAN_DEV")

    # If the IPv6 address is unchanged, lets just exit
    if [ "$WAN_6_OLD" = "$WAN_6_NEW" ]; then
        echo "Public IPv6 on $LAN_DEV unchanged: $WAN_6_OLD"
        exit
    fi
fi

# If $WAN_6_OLD does not exist, then we are just setting to the $WAN_6_NEW address
if [ -n "$WAN_6_OLD" ]; then
    echo "Updating IPv6 $WAN_6_OLD -> $WAN_6_NEW"
else
    echo "Setting IPv6 $WAN_6_NEW"
fi

echo "Applying config..."

# Apply config, commit, save
apply_config && commit && save

exit

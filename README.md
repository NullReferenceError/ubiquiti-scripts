# ubiquiti-scripts
Helper scripts to get more out of ubiquiti


## Details of files in this repository

* enable-ipv6-6rd.sh - This script utilizes latest VyOS configuration (as of 5/12/2020) for Unifi Security Gateway to configure an IPv6 over 6RD tunnel. The script should be placed in /etc/ppp/ip-up.d/ to run when a PPP interface comes up, and will automatically get the current IPv4 address, calculate the valid IPv6 address, compare if it's a new configuration or not (currently for Centurylink) and push the configuration to the VyOS gateway config. There are several options available also (debug for more logging, a "clean" property that removes all of the configured IPv6 configurations before pushing new ones). 

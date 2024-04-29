#!/bin/bash
# Define variables
mgmt_ip="138.203.15.91"
interface_name="ethernet-1/1"
N=400  # Number of iterations, define as needed
# Function for deploy mode
deploy() {
    # Run the non-iterative command
    gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set \
        --update-path "/interface[name=$interface_name]/admin-state" --update-value "enable" \
        --update-path "/interface[name=$interface_name]/vlan-tagging" --update-value "true"

    # Variables for iteration
    prefix="beef::0/127"
    ndx=1

    # Iterate as specified
    for (( i=0; i<$N; i++ )); do
        # Calculate the next IPv6 prefix
        ip=$(echo $prefix | cut -d'/' -f1)  # Get the IP part before the slash
        prefix_len=$(echo $prefix | cut -d'/' -f2)  # Get the prefix length after the slash
        next_ip=$(python -c "import ipaddress; print(str(ipaddress.ip_address('$ip') + 2))")
        prefix="$next_ip/$prefix_len"  # Combine them with updated IP

        # Run the iterative command
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set \
            --update-path "/interface[name=$interface_name]/subinterface[index=$ndx]/vlan/encap/single-tagged/vlan-id" --update-value "$ndx" \
            --update-path "/interface[name=$interface_name]/subinterface[index=$ndx]/ipv6/admin-state" --update-value "enable" \
            --update-path "/interface[name=$interface_name]/subinterface[index=$ndx]/ipv6/address[ip-prefix=$prefix]/primary" --update-value "{}" \
            --update-path "/network-instance[name=default]/interface[name=$interface_name.$ndx]" --update-value "{}" \
            --update-path "/network-instance[name=default]/protocols/bgp/dynamic-neighbors/interface[interface-name=$interface_name.$ndx]/peer-group" --update-value "scaling"

        # Increment ndx for the next iteration
        ndx=$((ndx + 2))
    done
}

# Function for destroy mode
destroy() {
    # Variables for iteration
    ndx=1
    for (( i=0; i<$N; i++ )); do
        # Run the destroy command
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set \
            --delete "/network-instance[name=default]/protocols/bgp/dynamic-neighbors/interface[interface-name=$interface_name.$ndx]" \
            --delete "/network-instance[name=default]/interface[name=$interface_name.$ndx]" \
            --delete "/interface[name=$interface_name]/subinterface[index=$ndx]"
        
        # Increment ndx for the next iteration
        ndx=$((ndx + 2))
    done
}

# Check the script's mode argument
case "$1" in
    deploy) deploy ;;
    destroy) destroy ;;
    *) echo "Usage: $0 [deploy|destroy]" ;;
esac
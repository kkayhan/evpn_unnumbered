#!/bin/bash

# Define Variables
mgmt_ip="leaf1"
interface_name="ethernet-1/13"
N=4  # Set this to the number of iterations you want

# Function to deploy configurations
deploy() {
    # Execute these commands only once for setup
    gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/interface[name=$interface_name]/admin-state" --update-value "enable"
    gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/interface[name=$interface_name]/vlan-tagging" --update-value "true"

    # Loop to execute commands N times with iterate increasing by 2 each time
    for (( iterate=2; iterate<2*N; iterate+=2 ))
    do
        prefix="beef::$iterate/127"

        # Execute commands using gnmic
        #gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/interface[name=$interface_name]/subinterface[index=$iterate]/admin-state" --update-value "enable"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/interface[name=$interface_name]/subinterface[index=$iterate]/vlan/encap/single-tagged/vlan-id" --update-value "$iterate"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/interface[name=$interface_name]/subinterface[index=$iterate]/ipv6/admin-state" --update-value "enable"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/interface[name=$interface_name]/subinterface[index=$iterate]/ipv6/address[ip-prefix=$prefix]/primary" --update-value "{}"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/network-instance[name=default]/interface[name=$interface_name.$iterate]" --update-value "{}"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --update-path "/network-instance[name=default]/protocols/bgp/dynamic-neighbors/interface[interface-name=$interface_name.$iterate]/peer-group" --update-value "scaling"
    done
}

# Function to destroy configurations
destroy() {
    # Loop to execute delete commands N times with iterate increasing by 2 each time
    for (( iterate=2; iterate<2*N; iterate+=2 ))
    do
        prefix="beef::$iterate/127"

        # Execute commands using gnmic
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --delete "/network-instance[name=default]/protocols/bgp/dynamic-neighbors/interface[interface-name=$interface_name.$iterate]"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --delete "/network-instance[name=default]/interface[name=$interface_name.$iterate]"
        gnmic --skip-verify -a "$mgmt_ip" -u admin -p 'NokiaSrl1!' -e json_ietf set --delete "/interface[name=$interface_name]/subinterface[index=$iterate]"
    done
}

# Check arguments for deploy or destroy
if [[ $1 == "deploy" ]]; then
    deploy
elif [[ $1 == "destroy" ]]; then
    destroy
else
    echo "Invalid argument: please use 'deploy' or 'destroy'"
    exit 1
fi

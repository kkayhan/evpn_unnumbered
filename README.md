# evpn-fabric — eBGP IPv6-unnumbered + EVPN-VXLAN (SR Linux)

A [containerlab](https://containerlab.dev) topology of a small Clos data-centre fabric built on Nokia SR Linux **26.3.2**. The fabric runs a **single eBGP session per leaf↔spine link over IPv6 unnumbered**, carrying both the `ipv4-unicast` underlay (system loopbacks) and the `evpn` overlay. Tenant connectivity is delivered with symmetric IRB (L2 + L3 EVPN-VXLAN), all-active ESI multi-homing, and a transparent out-of-band management bridge.

## Topology

See `evpn-fabric.clab.drawio` for the topology diagram.

- **Spines** — `rack1-data-spine1`, `rack2-data-spine1` (7220 IXR-H2). Pure EVPN transit (not VTEPs).
- **Leaves** — `rack1-data-leaf1/2`, `rack2-data-leaf1` (7220 IXR-D2L). VTEPs.
- **OOB leaves** — `rack1-oob-leaf1` (7220 IXR-D1), `rack2-oob-leaf1` (7215 IXS-A1). Pure transparent L2, no BGP.
- **Hosts** — `srv*`, `vrrp*`, `mgmt-1a/b` (network-multitool).

## Design

| Aspect | Choice |
|---|---|
| Fabric peering | eBGP, **IPv6 unnumbered** (RA-driven dynamic neighbours), one session/link |
| Address families | `ipv4-unicast` (loopbacks via `announce_system_IP` export policy) + `evpn` |
| Spine ASN | **shared `65100`** on both spines → AS-path loop-prevention stops leaf-transit-between-spines (RFC 7938 style) |
| Leaf ASN | unique per leaf (`65113`/`65114`/`65115`) |
| EVPN transit | `afi-safi evpn evpn inter-as-vpn true` on every node so the spine relays EVPN across the AS boundary |
| ECMP | `multipath allow-multiple-as true` (needed for ESI aliasing across the leaf pair) |
| Overlay services | symmetric IRB — `macvrf-rack1` (L2VNI 110, `192.0.2.0/24`), `macvrf-rack2` (L2VNI 120, `192.0.3.0/24`), one `ipvrf-tenant` (L3VNI 100) |
| Multi-homing | all-active EVPN ethernet-segments on leaf1+leaf2 (`es-srv1-1`/`lag1`, `es-vrrp-1`/`lag2`); hosts run a single LACP bond |
| OOB management | OOB leaves bridge each MGMT host transparently up to a **local mac-vrf on leaf1** (no EVPN) |
| System loopbacks | `10.10.10.0/24` — last octet matches the node’s `.X` label |

System loopbacks: spine1 `10.10.10.16`, spine2 `10.10.10.17`, leaf1 `.13`, leaf2 `.14`, leaf3 `.15`, oob1 `.11`, oob2 `.12`.

## Deploy

```bash
sudo containerlab deploy -t evpn-fabric.clab.yaml
# after editing any startup-config, force a fresh load:
sudo containerlab deploy -t evpn-fabric.clab.yaml --reconfigure
sudo containerlab destroy -t evpn-fabric.clab.yaml --cleanup
```

Requires the `ghcr.io/nokia/srlinux:26.3.2` and `ghcr.io/srl-labs/network-multitool` images.

## Verify

```bash
# intra-rack L2 (same BD, dual-homed)
docker exec srv1-1 ping -c2 192.0.2.12
# cross-rack L3 (symmetric IRB over L3VNI 100)
docker exec srv1-1 ping -c2 192.0.3.12
# OOB transparent L2 bridge
docker exec mgmt-1a ping -c2 192.168.99.12

# control plane (interactive SR Linux session — pw NokiaSrl1!)
ssh admin@clab-evpn-fabric-rack1-data-leaf1
# show network-instance default protocols bgp neighbor
# show system network-instance ethernet-segments summary
# show network-instance ipvrf-tenant route-table ipv4-unicast
```

## Layout

```
evpn-fabric.clab.yaml                 # topology (nodes, links, host bonds)
configs/startup_configs/*.cfg         # per-node SR Linux set-CLI startup configs
evpn-fabric.clab.drawio               # topology diagram
```

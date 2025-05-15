### UniFi Home / Lab Network — Current State Map (May 2025)

```text
      ┌───────────────────────────────────────────────────────────┐
      │  Apartment ISP uplink                                     │
      │  (RJ-45 wall jack, public /25)                            │
      └──────────────┬────────────────────────────────────────────┘
                     │  ( 23.252.56.60/25 — DHCP on WAN)
             eth2 / WAN1
┌──────────────────────────┐
│ **USG-Pro 4**            │  ▸ Gateway & firewall  
│  HW rev r2               │  ▸ LAN GW IP 192.168.1.1/24  
│  Firmware 4.4 x          │  ▸ DHCP Server ON  
│                          │    • Pool 192.168.1.6 – .254  
│                          │    • DNS handed-out → 192.168.1.227  
│                          │  ▸ DNS *for USG itself*       
│                          │    1. 1.1.1.1 (Cloudflare)  
│                          │    2. 9.9.9.9 (Quad9)  
│                          │    3–4. 208.76.152.1 / .9 (ISP via DHCP)  
│                          │  ▸ Connectivity monitor: ICMP 8.8.8.8, DNS via 1.1.1.1  
└──────────────┬───────────┘
               │ trunk (1 GbE)
         LAN switch uplink (untagged VLAN 1)
┌──────────────────────────────────────────┐
│ **UniFi 24-Port PoE Switch** (US-24-250) │
│  Mgmt IP: 192.168.1.3 (reserved)         │
└──────────────┬──────────────┬────────────┘
               │              │
         ┌─────┘              └──────┐
         │                           │
 wired 1 GbE                     wired 1 GbE
┌────────────────────────┐   ┌───────────────────────────────────┐
│ **Cloud Key G2**       │   │ **Pi-hole** (RPi 4)               │
│  UniFi OS 4.x          │   │  IP 192.168.1.227                 │
│  IP 192.168.1.2        │   │  Upstream DNS: 1.1.1.1 / 9.9.9.9  │
│  Access: /system       │   └───────────────────────────────────┘
│          /network      │
└──────────────┬─────────┘
               │ PoE
        ┌────────────────────┐
        │ **UniFi U6-LR AP** │  dual-band Wi-Fi 6
        │  Mgmt IP DHCP      │  SSID(s): default, no VLANs
        │                    │  Clients → IP 192.168.1.x, GW 192.168.1.1,
        └────────────────────┘              DNS 192.168.1.227

```

| Element                          | Key configuration • status                                                                   |
| -------------------------------- | -------------------------------------------------------------------------------------------- |
| **WAN (eth2)**                   | Public IP 23.252.56.60/25 obtained via DHCP from building ISP.                               |
| **LAN (192.168.1.0/24)**         | Gateway 192.168.1.1, DHCP active, no VLANs.                                                  |
| **DNS flow for clients**         | Client → Pi-hole 192.168.1.227 → Cloudflare / Quad9 upstream.                                |
| **DNS for USG itself**           | 1.1.1.1 → 9.9.9.9 → 208.76.152.1 / .9. First server healthy, so connectivity-monitor passes. |
| **Connectivity monitor targets** | ICMP 8.8.8.8 · DNS via first WAN DNS (1.1.1.1).                                              |
| **Controller**                   | Cloud Key reachable on `https://192.168.1.2/` (`/system`, `/network`).                       |
| **Security / NAT**               | Default UniFi rules; no custom port-forwards noted.                                          |
| **Open issues**                  | None outstanding; banner cleared, CK UI on :443 is functional.                               |

---

#### At-a-glance health

| Check                                 | Result                            |
| ------------------------------------- | --------------------------------- |
| Controller Dashboard                  | All devices **Connected / Green** |
| `ping 8.8.8.8 interface eth2 count 5` | < 1 ms avg, 0 % loss              |
| `host dl.ui.com 1.1.1.1`              | Instant resolve                   |
| `show dns forwarding nameservers`     | List starts with 1.1.1.1, 9.9.9.9 |
| `df -h` on Cloud Key                  | Free space OK; SD card healthy    |

---

### What to keep an eye on

1. **ISP DHCP renewals** – confirm WAN stays on a subnet different from LAN.
2. **Pi-hole uptime** – if it reboots, clients rely on lease refresh or secondary resolvers.
3. **Firmware currency** – UniFi OS & Network updates correct UI and monitoring quirks.
4. **Back-ups** – export network config and Pi-hole lists after major changes.

---

## Detailed Walk-through of Your Network

1. **Internet Edge** – Your apartment wall jack delivers a public IPv4 address directly to the USG-Pro 4 on interface `eth2`. Because the ISP uses DHCP, the gateway renews its lease and DNS hints automatically; no modem or PPPoE layer exists.

2. **Gateway / Firewall (USG-Pro 4)** –

   * **Addressing** – LAN set to 192.168.1.0/24 with the USG itself at 193.168.1.1. DHCP hands out addresses .6 – .254 and tells clients their DNS server is Pi-hole at 192.168.1.227.
   * **Self-DNS** – The USG’s own resolver list starts with Cloudflare (1.1.1.1) and Quad9 (9.9.9.9); ISP DNS servers trail as tertiary options, ensuring UniFi’s health checks stay green even if Pi-hole is down.
   * **Connectivity monitor** – Every 30 seconds the USG pings 8.8.8.8 and performs a DNS lookup of `unifi.ui.com` via 1.1.1.1. Both succeed, so the controller reports “Connected”.

3. **Distribution / Access Layer** – A UniFi 24-port PoE switch (US-24-250) receives the LAN trunk from the USG. It powers the Cloud Key and Access Point. No VLAN tagging is configured—everything runs on the default VLAN 1.

4. **Controller (Cloud Key Gen 2)** –

   * Runs UniFi OS 4.x; all applications are front-ended by nginx on port 443.
   * Accessible locally at `https://192.168.1.2/system` (OS dashboard) or `/network` (Network application).
   * Remote management via *unifi.ui.com* is also operational.
   * SD card is healthy; no 404 errors now that you use port 443 instead of legacy 8443.

5. **Wireless** – A UniFi U6-LR access point bridges wireless clients straight onto the flat LAN. Clients obtain DHCP from the USG, route Internet traffic via 192.168.1.1, and resolve all names through Pi-hole, enjoying ad-blocking at the network edge.

6. **DNS Flow** –

   * **Clients** → Pi-hole (192.168.1.227)
   * **Pi-hole** → Cloudflare (1.1.1.1) and Quad9 (9.9.9.9)
   * **USG health checks** bypass Pi-hole, hitting 1.1.1.1 directly to avoid circular dependency.
     This design isolates ad-blocking to user traffic while keeping gateway diagnostics independent.

7. **Current State** – All devices are adopted, online, and reporting. No overlapping subnets, DHCP conflicts, or failing probes remain. The network is operating exactly as UniFi expects for a single-LAN, Pi-hole-enhanced environment.
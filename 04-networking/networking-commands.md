# Networking Homework

Common networking commands with real output captured on this machine, plus a
short explanation of what each command does. On Linux the tool names differ
slightly (shown in each section).

---

## 1. `ping` — test reachability & latency

Sends ICMP echo requests to a host and measures round-trip time. Confirms a host
is up and the network path works.

- Linux: `ping -c 2 8.8.8.8`
- Windows / PowerShell: `Test-Connection -Count 2 8.8.8.8`

```text
   Destination: 8.8.8.8

Ping Source Address Latency(ms) BufferSize(B) Status
---- ------ ------- ----------- ------------- ------
   1 Varun  8.8.8.8         218            32 Success
   2 Varun  8.8.8.8         493            32 Success
```

**Understood:** both packets reached Google's `8.8.8.8` DNS server successfully,
so outbound internet connectivity is working. Latency was ~218–493 ms.

---

## 2. DNS lookup — `nslookup` / `dig` / `Resolve-DnsName`

Resolves a domain name to its IP address(es) by querying DNS.

- Linux: `nslookup github.com` or `dig github.com`
- PowerShell: `Resolve-DnsName github.com -Type A`

```text
Name       Type IPAddress
----       ---- ---------
github.com    A 140.82.121.4
```

**Understood:** the hostname `github.com` maps to the IPv4 address
`140.82.121.4` (an `A` record). DNS is the phonebook of the internet — this is
the step that turns a name into a routable address.

---

## 3. `curl` — make an HTTP request

Transfers data to/from a URL. `curl -I` fetches only the response **headers**,
which is handy for checking status codes and server info.

`curl -sI https://example.com`

```text
HTTP/1.1 200 OK
Date: Thu, 03 Sep 2026 16:31:01 GMT
Content-Type: text/html
Connection: keep-alive
Server: cloudflare
last-modified: Wed, 02 Sep 2026 22:14:26 GMT
allow: GET, HEAD
Accept-Ranges: bytes
```

**Understood:** the server responded `200 OK`, so the site is reachable over
HTTPS. The headers reveal it's fronted by Cloudflare and serves `text/html`.

---

## 4. Interface addresses — `ip addr` / `ifconfig` / `Get-NetIPAddress`

Lists the network interfaces on the machine and their assigned IP addresses.

- Linux: `ip addr` (modern) or `ifconfig` (legacy)
- PowerShell: `Get-NetIPAddress -AddressFamily IPv4`

```text
InterfaceAlias               IPAddress
--------------               ---------
ProTUN                       10.2.0.2
Wi-Fi                        100.128.161.201
Loopback Pseudo-Interface 1  127.0.0.1
Ethernet                     169.254.41.206
...
```

**Understood:** the machine has several interfaces — a Wi-Fi adapter
(`100.128.161.201`), a VPN tunnel (`ProTUN 10.2.0.2`), and the loopback
`127.0.0.1` (always points back to the local machine). `169.254.x.x` addresses
are APIPA/link-local (no DHCP lease on that adapter).

---

## 5. Other essential networking commands

These are part of the standard cheat sheet. Run them on a Linux host and paste
the output/screenshots here.

| Command | Purpose |
|---------|---------|
| `traceroute host` (Linux) / `tracert host` (Win) | Show every router hop between you and the destination |
| `netstat -tulnp` / `ss -tulnp` | List listening ports and the processes bound to them |
| `ip route` / `route -n` | Show the kernel routing table (default gateway) |
| `wget URL` | Download a file over HTTP/HTTPS |
| `telnet host port` / `nc -zv host port` | Test whether a specific TCP port is open |
| `hostname -I` | Print the machine's IP address(es) |
| `arp -a` | Show the ARP cache (IP ↔ MAC mappings) |
| `nslookup -type=MX domain` | Look up mail (MX) records |
| `mtr host` | Live combination of ping + traceroute |

Example (Linux):

```bash
ss -tulnp            # which services are listening, on which ports
ip route             # default gateway / routing table
traceroute google.com
nc -zv github.com 443   # is TCP 443 reachable?
```

---

## Summary

| Command | One-line meaning |
|---------|------------------|
| `ping` | Is the host reachable, and how fast? |
| `nslookup` / `dig` | What IP does this name resolve to? |
| `curl` | Make an HTTP request / inspect headers |
| `ip addr` / `ifconfig` | What are my interfaces and IPs? |
| `traceroute` | What path do packets take to the host? |
| `netstat` / `ss` | What ports am I listening on? |
| `ip route` | What's my default gateway / routing table? |

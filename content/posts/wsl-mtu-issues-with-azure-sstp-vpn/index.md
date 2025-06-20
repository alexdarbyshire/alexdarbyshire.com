---
title: "WSL MTU Issues with Azure SSTP VPN Connections"
date: 2025-06-20T21:26:00+10:00
author: "Alex Darbyshire"
slug: "wsl-mtu-issues-azure-sstp-vpn"
toc: true
tags:
  - Azure
  - WSL
  - Networking
  - Docker
  - Kubernetes
---

Azure VPN Gateway's SSTP Point-to-Site (P2S) connections to private VNETs can cause networking issues in WSL. Symptoms include hanging SSL connections, frozen database clients, and DB clients failing in Docker/Kubernetes networks. I encountered this with a SSL secured MySQL connection which would just hang with nothing informative. Worked fine from the Windows host.

The culprit: MTU mismatches.

## The Problem

MTU (Maximum Transmission Unit) is the largest packet size that can be transmitted over a network connection. Windows adjusts its MTU automatically when connecting via SSTP, but WSL doesn't reliably inherit this setting. If VPN connects before WSL starts, it might work. If after, problems begin. For Azure SSTP VPNs, the VPN operatues with a 1400 MTU and any NIC using should be set at 1350 to handle the overhead. Docker won't inherit from WSL.

## Symptoms

* SSL/TLS connections hang silently
* Database connections freeze during handshake
* Mongo import issues
* No error messages - just timeouts

## Diagnosis

I didn't figure it out this way. Retrospectively, I should have. There is often that moment after solving a problem where you realise 'ahh, I should have just looked at log x' - the answer is so often in the logs rather than the brute force first principles approach.

Packet capture shows:
* TCP SYN packets sent
* SYN-ACK packets received
* No ACK packets from WSL

WSL sends packets exceeding maximum tunnel size, leading to fragmentation or dropped packets.

## Solutions

### Fix WSL Network Interface

Add to `/etc/wsl.conf`:

```conf
[boot]
command = /sbin/ifconfig eth0 mtu 1350
```

### Fix Docker Network MTU

Update `/etc/docker/daemon.json`:

```json
{
  "mtu": 1350
}
```

Restart Docker:

```bash
sudo systemctl restart docker
```

### Important Notes

* **Existing Docker networks:** Remove and recreate after changing daemon.json:
  ```bash
  docker network ls
  docker network rm <network-name>
  ```

Local Kubernetes like Kind or Minikube will need adjustment to. Bringing them down and up should do the trick, check their VNETs MTUs with `ifconfig`

## Verification

Check after restarting WSL and Docker:

```bash
# WSL interface
ifconfig eth0 | grep mtu

# Docker bridge
docker network inspect bridge -f '{{.Options.com.docker.network.driver.mtu}}'
```

Both should show 1350 with the issue being resolved.

I spent a the better part of a day messing around figuring this out, probably would have been quicker if I had used Wireshark early on. Hope this post saved someone a little time getting to the bottom of it.



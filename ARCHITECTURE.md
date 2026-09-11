# Architecture & Design Decisions

This document explains *why* the infrastructure was built this way — not
just what was built — including alternatives considered and rejected.

## 1. Docker Compose over Kubernetes
A single VM hosting six services doesn't need an orchestrator. Kubernetes
adds a control plane, networking layer, and operational overhead that
only pays off at multi-node scale or when you need autoscaling/self-healing
across hosts. For a lab environment on one server, Compose gives the same
declarative service definitions with a fraction of the complexity.

## 2. Nginx as the single exposed entry point
Only Nginx binds to host ports 80/443. Flask and PostgreSQL stay on the
internal Docker network with no host port mapping at all. This means an
attacker scanning the host only ever sees one service, and the app/db
containers are unreachable even if Nginx is compromised at the network
layer — they're not listening on the host's interfaces to begin with.

## 3. Internal-only Flask and PostgreSQL
Rejected alternative: publishing 5000/5432 to the host "for easier
debugging." That would mean every process on the LAN could hit the app
or database directly, bypassing Nginx entirely. Docker's internal
network already gives Nginx and the app what they need to talk to each
other; there's no operational reason to widen that.

## 4. `expose:` instead of `ports:` for Prometheus and Node Exporter
Docker manipulates iptables directly when you use `ports:`, which bypasses
UFW regardless of the firewall's own rules — so `ports: ["9090:9090"]`
would make Prometheus reachable from anywhere on the LAN even though UFW
only allows 2222/80/443. Switching to `expose:` keeps the scrape targets
reachable inside the Docker network (Prometheus can still reach Node
Exporter and cAdvisor) without punching a host-level hole. Access for
verification is via an SSH tunnel (`ssh -L 9090:localhost:9090`) instead.

## 5. Self-signed TLS instead of Let's Encrypt
Let's Encrypt requires a publicly resolvable domain name and port 80/443
reachable from the internet for ACME validation. This is a LAN-only lab
VM with a private IP (192.168.1.133) — there's no domain to validate
against, so a CA-issued cert isn't obtainable here. Self-signed is the
correct choice for this environment; the README notes this would be
swapped for a real CA cert in production.

## 6. UFW *and* an SSH tunnel, not just one or the other
UFW alone doesn't protect against Docker's iptables manipulation (see #4).
An SSH tunnel alone doesn't stop someone from adding a `ports:` mapping
later and reopening the hole. Using both means the firewall enforces the
policy at the host level, and the tunnel provides the working exception
for legitimate access — two independent layers instead of relying on one
mechanism to catch everything.

## 7. Named Docker volume for PostgreSQL, not a bind mount
A named volume is managed by the Docker daemon, survives `docker compose
down` (without `--volumes`), and isn't tied to a specific host path —
making it portable if the compose file moves between machines. A bind
mount would tie persistence to one exact directory on this VM.

## 8. Feature branches merged via explicit merge commits
Rejected alternative: squash-merging or committing everything straight to
`main`. Explicit merges preserve the branch structure in `git log --graph`,
so the history shows *which work happened together* (e.g. all of Task 2's
Docker setup as one traceable unit) rather than a flat, undifferentiated
commit list.

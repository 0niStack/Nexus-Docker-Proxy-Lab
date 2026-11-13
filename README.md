# Nexus Docker Proxy Lab (Nginx + Traefik, HTTPS on IP)

```
nexus-proxy-lab/
├── 01-nexus-nginx/      Nexus + Nginx   (DockerHub proxy at /v2, hosted repo at /v2/hosted)
├── 02-nexus-traefik/    Nexus + Traefik (DockerHub proxy at /v2, proxy of 01's hosted repo at /v2/hosted)
└── scripts/client-trust.sh
```

Default = **IP + self-signed HTTPS**. Domain / Let's Encrypt lines are commented out in
`setup.sh`, `nginx.conf` and `dynamic/routes.yml`.

## 01 - Nexus + Nginx (VM 1)
```bash
cd 01-nexus-nginx
SERVER_IP=<VM1_IP> ./setup.sh
sudo cat nexus-data/admin.password     # login as admin, set a new password
```
In Nexus UI -> Settings -> Repositories -> Create (docker):

| Name         | Type   | HTTP port | Remote / notes                                   |
|--------------|--------|-----------|--------------------------------------------------|
| dockerhub    | proxy  | 8082      | Remote `https://registry-1.docker.io`, Docker Index = *Use Docker Hub* |
| hosted       | hosted | 8083      | Enable Docker V1 API off; allow redeploy as you like |

Also: Security -> Realms -> add **Docker Bearer Token Realm**.

## 02 - Nexus + Traefik (VM 2)
```bash
cd 02-nexus-traefik
SERVER_IP=<VM2_IP> ./setup.sh
```
Create two docker **proxy** repos:

| Name          | HTTP port | Remote URL                          |
|---------------|-----------|-------------------------------------|
| dockerhub     | 8082      | `https://registry-1.docker.io` (Use Docker Hub) |
| nginx-hosted  | 8083      | `https://<VM1_IP>`  (the 01 Nexus)  |

Because VM1 uses a self-signed cert, edit `nginx-hosted` -> Remote storage ->
tick **Use certificate stored in the Nexus truststore** -> **View certificate** -> **Add certificate to truststore**.
Also add the Docker Bearer Token Realm, and set the proxy's remote auth (admin / password of VM1) if anonymous pull is off.

## Docker clients
```bash
sudo scripts/client-trust.sh <VM1_IP> 01-nexus-nginx/certs/fullchain.pem
sudo scripts/client-trust.sh <VM2_IP> 02-nexus-traefik/certs/fullchain.pem
```
(Copy each `fullchain.pem` from the VM first.) Alternative: add the IP to `insecure-registries` in `/etc/docker/daemon.json` and restart Docker.

## Test
```bash
# 01
docker login <VM1_IP> -u admin
docker pull <VM1_IP>/nginx:latest                      # via DockerHub proxy
docker pull busybox
docker tag busybox:latest <VM1_IP>/hosted/busybox:latest
docker push <VM1_IP>/hosted/busybox:latest             # hosted repo

# 02
docker login <VM2_IP> -u admin
docker pull <VM2_IP>/nginx:latest                      # DockerHub via Traefik Nexus
docker pull <VM2_IP>/hosted/busybox:latest             # fetched from 01 via proxy
```

## Switching to a domain
1. Point DNS to the VM, get certs with certbot (commented block in `setup.sh`), put `fullchain.pem` / `privkey.pem` in `certs/`.
2. 01: set `server_name` to your domain in both server blocks of `config/nginx.conf`.
3. 02: switch the commented `Host(...)` rules in `dynamic/routes.yml`.
4. `docker compose up -d` (Traefik reloads routes automatically). Update the `nginx-hosted` remote URL to the domain; no truststore step needed for Let's Encrypt.

## Notes / fixes vs. the original article
- `events {}` block in nginx.conf was missing its closing brace.
- Traefik routes use the file provider (no `docker.sock` mount, no insecure API); port mapping matches 01 (8082 = DockerHub, 8083 = hosted-proxy). Longest prefix `/v2/hosted` has higher priority than `/v2`.
- `chown 200:200 nexus-data` instead of `chmod 777`.

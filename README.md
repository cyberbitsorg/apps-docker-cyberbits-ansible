# Docker apps for cyberbits.org

Docker container orchestration with Ansible. Cloud agnostic: works on any Docker host.

## Domain name resolution required

Before running this playbook, you MUST ensure your domain names correctly resolve to your servers.

Let's Encrypt requires valid DNS records to issue SSL certificates:
- Create A records (or AAAA for IPv6) pointing your domain(s) to your server's IP
- Wait for DNS propagation (can take minutes to hours)
- Verify with `dig +short sub.yourdomain.com @1.1.1.1`

Without proper DNS resolution, SSL certificate generation will fail and your sites won't be accessible via HTTPS. Also, this will result in (temporary) Let's Encrypt bans, which are a real PITA when you want to set things up.

---

## Structure

```
.
├── ansible.cfg
├── inventory/
│   ├── hosts.yaml
│   ├── hosts.yaml.example
│   └── group_vars/
│       ├── all.yaml                     # Global settings
│       ├── nginx_apps.yaml              # Nginx app configs
│       ├── wordpress_apps.yaml          # WordPress app configs
│       └── nextcloud_apps.yaml          # Nextcloud app configs
├── playbooks/
│   ├── deploy-traefik.yaml          # Deploy reverse proxy first
│   ├── deploy-nginx_apps.yaml       # Static HTML apps
│   ├── deploy-wordpress_apps.yaml   # WordPress apps
│   └── deploy-nextcloud_apps.yaml   # Nextcloud apps
└── roles/
    ├── common/                      # Docker networks
    ├── traefik/                     # Reverse proxy
    ├── nginx-apps/                  # Static apps
    ├── wordpress-apps/              # WordPress multi-app
    └── nextcloud-apps/              # Nextcloud multi-app
```

## Requirements

- Target server with Docker installed
- Ansible 2.15+
- SSH access to target server
- DNS records pointing your domains to the server

## Architecture

Traefik runs as the central reverse proxy. All applications connect to the `traefik` network and get automatic SSL certificates via Let's Encrypt.

## Quick Start

### 1. Configure Inventory

Edit the `inventory/hosts.yaml` to match your requirements.

### 2. Deploy Traefik

```bash
ansible-playbook playbooks/deploy-traefik.yaml
```

### 3. Deploy Applications

Choose which applications to deploy:

```bash
# Basic Nginx sites
ansible-playbook playbooks/deploy-nginx-apps.yaml

# Nextcloud instances
ansible-playbook playbooks/deploy-nextcloud-apps.yaml

# WordPress instances
ansible-playbook playbooks/deploy-wordpress-apps.yaml

# Or deploy everything at once
ansible-playbook playbooks/deploy-all.yaml
```

## Application Configuration

### Basic Nginx sites

Edit `inventory/group_vars/nginx_apps.yaml`:

```yaml
nginx_apps:
  - name: firstnx
    domain: firstnx.cyberbits.org
    title: "cyberbits.org"
    message: "Welcome to my first Nginx cyberbits.org"
    www_redirect: false
    # nginx_template: default   # see below for details
```

#### Adding an instance

Adding a site is as simple as duplicating an existing block and editing it as desired, but you might need a different template, depending on your site.

Select a template per site with the `nginx_template` field. Ansible deploys it automatically, no manual server-side configuration needed.

| Template | File | Use case |
|----------|------|----------|
| `default` (or omit) | `nginx-default.conf.j2` | Standard static site |
| `spa` | `nginx-spa.conf.j2` | Single Page App (React, Vue, Angular) — routes all requests to `index.html` |

To add your own template:

1. Create `roles/nginx-apps/templates/nginx-{name}.conf.j2`
2. Set `nginx_template: {name}` on the site in `nginx_apps.yaml`
3. Re-run the playbook

### Nextcloud instances

Edit `inventory/group_vars/nextcloud_apps.yaml`:

```yaml
nextcloud_apps:
  - name: cloud
    domain: cloud.example.com
    admin_user: admin
    # Optional settings:
    php_memory_limit: 1024M
    max_upload_size: 10G
    redis_maxmemory: 256mb
```

Optional Settings (with defaults):

| Setting | Default | Description |
|---------|---------|-------------|
| `php_memory_limit` | 1024M | PHP memory for Nextcloud |
| `max_upload_size` | 10G | Maximum file upload size |
| `redis_maxmemory` | 256mb | Redis cache size |

Adding an instance is as simple as duplicating an existing block and editing it as desired.

### WordPress instances

Edit `inventory/group_vars/wordpress_apps.yaml`:

```yaml
wordpress_apps:
  - name: blog
    domain: blog.example.com
    db_name: blog_wp
    db_user: blog_wp
    table_prefix: wp_
    www_redirect: false
    # Optional PHP settings (see all options below):
    php_memory_limit: 512M
    php_upload_max_filesize: 64M
```

Optional Settings (with defaults):

| Setting | Default | Description |
|---------|---------|-------------|
| `php_memory_limit` | 512M | PHP memory per request |
| `php_upload_max_filesize` | 64M | Maximum upload file size |
| `php_post_max_size` | 64M | Maximum POST data size |
| `php_max_execution_time` | 300 | Script timeout in seconds |
| `redis_maxmemory` | 128mb | Redis cache size |
| `redis_maxmemory_policy` | allkeys-lru | Redis eviction policy |

Adding an instance is as simple as duplicating an existing block and editing it as desired.

## License

MIT License. Free to use. No warranties.

# Container apps for any Docker host - setup with Ansible

Docker container orchestration with Ansible. Cloud agnostic: works on any Docker host.

Traefik runs as the central reverse proxy. All applications connect to the `traefik` network and get automatic SSL certificates via Let's Encrypt.

## Requirements

- Target server with Docker installed
- Ansible 2.15+
- SSH access to target server
- DNS records pointing your domains to the server

## Domain name resolution required

Before running this playbook, you MUST ensure your domain names correctly resolve to your servers.

Let's Encrypt requires valid DNS records to issue SSL certificates:
- Create A records (or AAAA for IPv6) pointing your domain(s) to your server's IP
- Wait for DNS propagation (can take minutes to hours)
- Verify with `dig +short sub.yourdomain.com @1.1.1.1`

Without proper DNS resolution, SSL certificate generation will fail and your sites won't be accessible via HTTPS. Also, this will result in (temporary) Let's Encrypt bans, which are a real PITA when you want to set things up.

## Secrets and vault

All application secrets (database passwords, WordPress keys/salts, Nextcloud admin passwords) are stored in `inventory/group_vars/all/vault.yaml`, encrypted with Ansible Vault. The file is safe to commit once encrypted.

Secrets are generated automatically from your app names.

### First setup

1. Configure your apps in `inventory/group_vars/wordpress_apps.yaml` and `nextcloud_apps.yaml`
2. Run the setup script:

```bash
./ansible-vault-setup.sh
```

This reads your app names, generates a strong random secret for each one, writes `vault.yaml`, and encrypts it. You will be prompted for a vault passphrase (saved to `.vault_pass`, gitignored) and for the sudo password of the deploy user.

You'll also need to add the deploy user sudo password to the `vault.yaml`:

```bash
# Sudo password for privilege escalation
ansible_become_password: "G905kmfwo2x50wdcftghuvYauOpn"
```

If you just encrypted the file, simple dsecrypt it and add it to the top.

```bash
ansible-vault decrypt inventory/group_vars/all/vault.yaml
```

Never forget to encrypt it again before committing.

As for the sudo password, if you provisioned the server with [infra-hetzner-vps-clean](https://github.com/cyberbitsorg/infra-hetzner-vps-clean), retrieve the sudo password from there:

```bash
# From Terraform output
tofu output -raw deployacc_sudo_password

# Or from its Ansible vault
ansible-vault view ansible/group_vars/all/vault.yaml
```

### Day-to-day vault commands

```bash
# Edit secrets
ansible-vault edit inventory/group_vars/all/vault.yaml

# View secrets
ansible-vault view inventory/group_vars/all/vault.yaml

# Decrypt file (don't commit your decrypted file!)
ansible-vault decrypt inventory/group_vars/all/vault.yaml
```

### Adding a new app with passwords

1. Add the app to `wordpress_apps.yaml` or `nextcloud_apps.yaml` in the `group_vars`
2. Re-run the setup script; it detects which apps are already in the vault and only generates secrets for new ones

```bash
./ansible-vault-setup.sh
```

## Deploying your apps

### 1. Apps and secrets

Make sure your apps an secrets are in place (see above).

### 2. Configure inventory

Edit the `inventory/hosts.yaml` to match your requirements.

### 3. Deploy Traefik

```bash
ansible-playbook playbooks/deploy-traefik.yaml
```

### 4. Deploy Applications

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

Skip a certain type of application by specifying an empty list in the appropriate `group_vars` file.

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

Adding an instance is as simple as duplicating an existing block and editing it as desired. Run `./ansible-vault-setup.sh` to generate passwords for your new app and add it to `vault.yaml`.

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

Adding an instance is as simple as duplicating an existing block and editing it as desired. Run `./ansible-vault-setup.sh` to generate passwords for your new app and add it to `vault.yaml`.

## License

MIT License. Free to use. No warranties.

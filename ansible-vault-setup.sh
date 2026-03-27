#!/usr/bin/env bash
set -euo pipefail

VAULT_PASS_FILE=".vault_pass"
VAULT_FILE="inventory/group_vars/all/vault.yaml"

# ---------------------------------------------------------------------------
# Vault password
# ---------------------------------------------------------------------------

if [ ! -f "$VAULT_PASS_FILE" ]; then
  read -rsp "Enter vault passphrase: " passphrase
  echo
  echo "$passphrase" > "$VAULT_PASS_FILE"
  chmod 600 "$VAULT_PASS_FILE"
  echo "Created $VAULT_PASS_FILE"
else
  echo "$VAULT_PASS_FILE already exists, skipping."
fi

# ---------------------------------------------------------------------------
# Work with a decrypted copy so we can check existing entries
# ---------------------------------------------------------------------------

TMPFILE=$(mktemp)
WORKFILE=$(mktemp)
trap 'rm -f "$TMPFILE" "$WORKFILE"' EXIT

if grep -q '^\$ANSIBLE_VAULT' "$VAULT_FILE" 2>/dev/null; then
  if ansible-vault view "$VAULT_FILE" &>/dev/null; then
    ansible-vault decrypt "$VAULT_FILE" --output "$WORKFILE"
  else
    echo "ERROR: $VAULT_FILE exists and is encrypted but could not be decrypted."
    echo ""
    echo "  - If this is a fresh setup (cloned repo): delete $VAULT_FILE and re-run."
    echo "  - If you have an existing vault: restore .vault_pass first, then re-run."
    exit 1
  fi
elif [ -f "$VAULT_FILE" ]; then
  cp "$VAULT_FILE" "$WORKFILE"
fi

# ---------------------------------------------------------------------------
# Generate secrets — only for apps not already present in the vault
# ---------------------------------------------------------------------------

gen() {
  python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32)))"
}

has_secret() {
  grep -q "^${1}:" "$WORKFILE" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Sudo password (ansible_become_password)
# ---------------------------------------------------------------------------

if has_secret "ansible_become_password"; then
  echo "  [skip] ansible_become_password (already in vault)"
else
  read -rsp "Enter sudo password for the deploy user: " become_pass
  echo
  { echo ""; echo "# Sudo password for privilege escalation"; echo "ansible_become_password: \"${become_pass}\""; } >> "$WORKFILE"
  echo "  [new]  ansible_become_password"
fi

wp_apps=$(grep -E '^\s*- name:' inventory/group_vars/wordpress_apps.yaml | awk '{print $3}')
nc_apps=$(grep -E '^\s*- name:' inventory/group_vars/nextcloud_apps.yaml | awk '{print $3}')

new_wp=0
new_nc=0

for name in $wp_apps; do
  if has_secret "${name}_mysql_root_password"; then
    echo "  [skip] $name (already in vault)"
    continue
  fi
  echo "  [new]  $name"
  {
    echo ""
    echo "# WordPress - $name"
    for key in mysql_root_password mysql_password \
                wp_auth_key wp_secure_auth_key wp_logged_in_key wp_nonce_key \
                wp_auth_salt wp_secure_auth_salt wp_logged_in_salt wp_nonce_salt; do
      echo "${name}_${key}: \"$(gen)\""
    done
  } >> "$WORKFILE"
  (( new_wp++ )) || true
done

for name in $nc_apps; do
  if has_secret "${name}_db_password"; then
    echo "  [skip] $name (already in vault)"
    continue
  fi
  echo "  [new]  $name"
  {
    echo ""
    echo "# Nextcloud - $name"
    for key in db_password admin_password; do
      echo "${name}_${key}: \"$(gen)\""
    done
  } >> "$WORKFILE"
  (( new_nc++ )) || true
done

if [[ $new_wp -eq 0 && $new_nc -eq 0 ]]; then
  echo "No new apps found."
else
  echo "Generated secrets for ${new_wp} new WordPress app(s) and ${new_nc} new Nextcloud app(s)."
fi

ansible-vault encrypt "$WORKFILE" --output "$VAULT_FILE"
echo "Done. $VAULT_FILE is encrypted and ready to commit."

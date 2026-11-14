set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

dir := module_directory()
scripts := dir / 'scripts'

# Matches ansible/edge/hosts.ini. Workstation-only: these recipes run from the
# Mac mini (the trusted bootstrap host), never from the VPS itself.
export EDGE_HOST := '139.99.135.40'
export EDGE_USER := 'ubuntu'
export EDGE_PORT := '22222'
export EDGE_KEY  := home_directory() / '.ssh/edge_ssh'

[doc('Check the 1Password seal-key reference is readable and well formed; prints no secrets')]
openbao-check-secrets:
    {{ scripts }}/check-secrets.sh 'op://kubernetes/openbao/OPENBAO_STATIC_SEAL_KEY'

[doc('Validate the compose file and config.hcl against the VPS its own docker compose')]
openbao-validate:
    {{ scripts }}/ssh-edge.sh 'rm -rf /tmp/ob-validate && mkdir -p /tmp/ob-validate/config'
    {{ scripts }}/scp-edge.sh "{{ dir }}/docker-compose.yaml" /tmp/ob-validate/docker-compose.yaml
    {{ scripts }}/scp-edge.sh "{{ dir }}/config/config.hcl" /tmp/ob-validate/config/config.hcl
    {{ scripts }}/ssh-edge.sh 'cd /tmp/ob-validate && OPENBAO_STATIC_SEAL_KEY=$(openssl rand -hex 32) docker compose config --quiet && echo "compose: valid"; rm -rf /tmp/ob-validate'
    python3 "{{ scripts }}/validate.py" config "{{ dir }}/config/config.hcl"

[doc('Create /opt/openbao/data on the VPS with the ownership the unprivileged image user needs')]
openbao-provision:
    {{ scripts }}/provision.sh "{{ scripts }}/ssh-edge.sh"

[doc('Show container and seal state on the VPS')]
openbao-status:
    {{ scripts }}/ssh-edge.sh 'sudo docker inspect openbao 2>/dev/null || echo "[]"' | python3 "{{ scripts }}/validate.py" inspect
    {{ scripts }}/ssh-edge.sh 'sudo docker exec openbao bao status' 2>/dev/null | grep -E '^(Seal Type|Recovery Seal Type|Initialized|Sealed|Version)' || echo "status=unavailable"

[doc('Initialize OpenBao once; writes recovery key + root token to a 0600 file for 1Password')]
openbao-init:
    {{ scripts }}/init.sh "{{ scripts }}/ssh-edge.sh" '.openbao-init.json' "{{ scripts }}/validate.py"

[doc('Ask Doco-CD to reconcile the edge stack now instead of waiting for its poll interval')]
openbao-deploy:
    {{ scripts }}/ssh-edge.sh 'sudo docker restart doco-cd >/dev/null && echo "doco-cd restarted; it re-polls on startup"'
    echo "Watch with: just edge openbao-status"

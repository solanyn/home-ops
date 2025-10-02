import requests
import os
import yaml

# Common apps that should exist in both repos
common_apps = [
    'network/cloudflare-dns',
    'network/unifi-dns', 
    'observability/gatus',
    'cert-manager/cert-manager',
    'external-secrets/external-secrets',
    'kube-system/cilium',
    'rook-ceph/rook-ceph'
]

def get_onedr0p_ks(app_path):
    url = f"https://raw.githubusercontent.com/onedr0p/home-ops/main/kubernetes/apps/{app_path}/ks.yaml"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            return response.text
        return None
    except:
        return None

def get_our_ks(app_path):
    filepath = f"kubernetes/apps/{app_path}/ks.yaml"
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            return f.read()
    return None

def compare_structure(our_yaml, their_yaml):
    try:
        # Parse first document only for comparison
        our_doc = yaml.safe_load(our_yaml.split('---')[0] if '---' in our_yaml else our_yaml)
        their_doc = yaml.safe_load(their_yaml.split('---')[0] if '---' in their_yaml else their_yaml)
        
        # Compare key structure
        our_keys = set(our_doc.get('spec', {}).keys()) if our_doc else set()
        their_keys = set(their_doc.get('spec', {}).keys()) if their_doc else set()
        
        missing = their_keys - our_keys
        extra = our_keys - their_keys
        
        return missing, extra
    except:
        return set(), set()

print("Comparing ks.yaml structure with onedr0p/home-ops:")
print("=" * 60)

for app in common_apps:
    print(f"\n📁 {app}")
    
    our_ks = get_our_ks(app)
    their_ks = get_onedr0p_ks(app)
    
    if not our_ks:
        print("  ❌ We don't have this app")
        continue
    if not their_ks:
        print("  ❌ They don't have this app (or 404)")
        continue
    
    missing, extra = compare_structure(our_ks, their_ks)
    
    if not missing and not extra:
        print("  ✅ Structure matches")
    else:
        if missing:
            print(f"  ⚠️  Missing keys: {missing}")
        if extra:
            print(f"  ℹ️  Extra keys: {extra}")


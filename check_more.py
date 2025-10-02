import requests
import os
import yaml

# Check more apps
more_apps = [
    'default/atuin',
    'default/plex', 
    'kube-system/metrics-server',
    'kube-system/reloader',
    'observability/kube-prometheus-stack'
]

def get_onedr0p_ks(app_path):
    url = f"https://raw.githubusercontent.com/onedr0p/home-ops/main/kubernetes/apps/{app_path}/ks.yaml"
    try:
        response = requests.get(url)
        return response.text if response.status_code == 200 else None
    except:
        return None

def get_our_ks(app_path):
    filepath = f"kubernetes/apps/{app_path}/ks.yaml"
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            return f.read()
    return None

def show_key_differences(our_yaml, their_yaml):
    try:
        our_doc = yaml.safe_load(our_yaml.split('---')[0])
        their_doc = yaml.safe_load(their_yaml.split('---')[0])
        
        # Check specific patterns
        our_spec = our_doc.get('spec', {})
        their_spec = their_doc.get('spec', {})
        
        # Check for our custom additions
        our_extras = []
        if 'commonMetadata' in our_spec and 'commonMetadata' not in their_spec:
            our_extras.append('commonMetadata')
        if 'components' in our_spec and 'components' not in their_spec:
            our_extras.append('components')
        if 'targetNamespace' in our_spec and 'targetNamespace' not in their_spec:
            our_extras.append('targetNamespace')
            
        return our_extras
    except:
        return []

for app in more_apps:
    print(f"\n📁 {app}")
    
    our_ks = get_our_ks(app)
    their_ks = get_onedr0p_ks(app)
    
    if not our_ks:
        print("  ❌ We don't have this app")
        continue
    if not their_ks:
        print("  ❌ They don't have this app")
        continue
    
    extras = show_key_differences(our_ks, their_ks)
    if extras:
        print(f"  ℹ️  Our additions: {extras}")
    else:
        print("  ✅ Core structure matches")


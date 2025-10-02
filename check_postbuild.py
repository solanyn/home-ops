import requests
import os
import yaml

# Apps that likely have postBuild substitutions
apps_with_postbuild = [
    'default/atuin',
    'default/plex',
    'default/ghost', 
    'observability/gatus',
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

def extract_postbuild(yaml_content):
    try:
        doc = yaml.safe_load(yaml_content.split('---')[0])
        postbuild = doc.get('spec', {}).get('postBuild', {})
        substitute = postbuild.get('substitute', {})
        return substitute
    except:
        return {}

print("Comparing postBuild substitute patterns:")
print("=" * 50)

for app in apps_with_postbuild:
    print(f"\n📁 {app}")
    
    our_ks = get_our_ks(app)
    their_ks = get_onedr0p_ks(app)
    
    if not our_ks:
        print("  ❌ We don't have this app")
        continue
    if not their_ks:
        print("  ❌ They don't have this app")
        continue
    
    our_subs = extract_postbuild(our_ks)
    their_subs = extract_postbuild(their_ks)
    
    if not our_subs and not their_subs:
        print("  ℹ️  Neither has postBuild")
        continue
    
    print(f"  Our substitutes: {our_subs}")
    print(f"  Their substitutes: {their_subs}")
    
    # Check for differences
    our_keys = set(our_subs.keys())
    their_keys = set(their_subs.keys())
    
    if our_keys != their_keys:
        missing = their_keys - our_keys
        extra = our_keys - their_keys
        if missing:
            print(f"  ⚠️  We're missing: {missing}")
        if extra:
            print(f"  ℹ️  We have extra: {extra}")
    else:
        print("  ✅ Same substitute keys")


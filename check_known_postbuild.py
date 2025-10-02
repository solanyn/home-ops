import requests
import yaml

# Check some apps we know onedr0p uses postBuild for
known_apps = [
    'default/bazarr',
    'default/radarr', 
    'default/sonarr',
    'default/prowlarr'
]

def get_onedr0p_ks(app_path):
    url = f"https://raw.githubusercontent.com/onedr0p/home-ops/main/kubernetes/apps/{app_path}/ks.yaml"
    try:
        response = requests.get(url)
        return response.text if response.status_code == 200 else None
    except:
        return None

def extract_postbuild(yaml_content):
    try:
        doc = yaml.safe_load(yaml_content.split('---')[0])
        return doc.get('spec', {}).get('postBuild', {}).get('substitute', {})
    except:
        return {}

for app in known_apps:
    print(f"\n📁 {app}")
    their_ks = get_onedr0p_ks(app)
    
    if their_ks:
        their_subs = extract_postbuild(their_ks)
        print(f"  onedr0p substitutes: {their_subs}")
    else:
        print("  ❌ Not found")


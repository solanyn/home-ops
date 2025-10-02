import os
import yaml
import glob

def process_ks_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Split multi-document YAML
    documents = content.split('---\n')
    modified = False
    
    for i, doc_content in enumerate(documents):
        if not doc_content.strip():
            continue
            
        try:
            doc = yaml.safe_load(doc_content)
            if not doc or 'spec' not in doc:
                continue
                
            postbuild = doc.get('spec', {}).get('postBuild', {})
            substitute = postbuild.get('substitute', {})
            
            if 'APP' in substitute:
                del substitute['APP']
                modified = True
                
                # If substitute is now empty, remove postBuild entirely
                if not substitute:
                    if 'postBuild' in doc['spec']:
                        del doc['spec']['postBuild']
                else:
                    doc['spec']['postBuild']['substitute'] = substitute
                
                # Convert back to YAML
                documents[i] = yaml.dump(doc, default_flow_style=False, sort_keys=False)
                
        except yaml.YAMLError:
            continue
    
    if modified:
        # Reconstruct the file
        new_content = '---\n'.join(documents)
        # Clean up extra separators
        new_content = new_content.replace('---\n\n---\n', '---\n')
        new_content = new_content.strip()
        
        with open(filepath, 'w') as f:
            f.write(new_content)
        
        return True
    return False

# Process all ks.yaml files
count = 0
for filepath in glob.glob('kubernetes/apps/**/ks.yaml', recursive=True):
    if process_ks_file(filepath):
        print(f"✅ Cleaned {filepath}")
        count += 1

print(f"\nProcessed {count} files")

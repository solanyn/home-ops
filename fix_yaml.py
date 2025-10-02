import yaml
import os
import glob

def fix_yaml_file(filepath):
    try:
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Try to parse to check if valid
        yaml.safe_load(content)
        return True, "Valid"
    except yaml.YAMLError as e:
        # Common fixes
        lines = content.split('\n')
        fixed = False
        
        for i, line in enumerate(lines):
            # Fix indentation issues
            if line.strip().startswith('- ../../../../components/volsync') and not line.startswith('    -'):
                lines[i] = '    - ../../../../components/volsync'
                fixed = True
            
            # Fix compact mapping issues
            if 'APP: *app  ' in line:
                parts = line.split('APP: *app  ')
                if len(parts) == 2:
                    indent = len(parts[0])
                    lines[i] = parts[0] + 'APP: *app'
                    lines.insert(i+1, ' ' * (indent + 2) + parts[1])
                    fixed = True
        
        if fixed:
            new_content = '\n'.join(lines)
            try:
                yaml.safe_load(new_content)
                with open(filepath, 'w') as f:
                    f.write(new_content)
                return True, "Fixed"
            except yaml.YAMLError:
                return False, f"Still invalid after fix: {str(e)}"
        
        return False, f"Error: {str(e)}"

# Find and fix all ks.yaml files
for filepath in glob.glob('kubernetes/apps/**/ks.yaml', recursive=True):
    valid, msg = fix_yaml_file(filepath)
    if not valid:
        print(f"❌ {filepath}: {msg}")
    elif msg == "Fixed":
        print(f"🔧 {filepath}: {msg}")

print("Done!")

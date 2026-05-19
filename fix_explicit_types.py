#!/usr/bin/env python3
"""
Fix explicit_type_interface violations in Swift files.
This script adds explicit type annotations to properties that are inferred.
"""
import re
import sys
from pathlib import Path

def infer_type_from_initializer(initializer):
    """Infer the Swift type from an initializer expression."""
    init = initializer.strip()

    # String literals
    if init.startswith('"') or init.startswith("'") or (init.startswith('"""') and '"""' in init):
        return 'String'

    # Int literals
    if re.match(r'^-?\d+$', init):
        return 'Int'

    # Double literals
    if re.match(r'^-?\d+\.\d+$', init):
        return 'Double'

    # Bool literals
    if init in ('true', 'false'):
        return 'Bool'

    # Array literals
    if init.startswith('[') and init.endswith(']'):
        # Check if it's an array of strings
        if '"' in init:
            # Try to determine element type
            inner = init[1:-1].strip()
            if inner:
                first_elem = inner.split(',')[0].strip()
                if first_elem.startswith('"'):
                    return '[String]'
        return '[String]'

    # Dictionary literals
    if init.startswith('[') and ':' in init and init.endswith(']'):
        # Heuristic: assume [String: String] for most cases
        return '[String: String]'

    # Default values
    if init == 'nil':
        return ''

    # URL construction
    if 'URL(string:' in init:
        return 'URL'

    # Tuple construction
    if init.startswith('(') and init.endswith(')'):
        return ''

    # Function calls - can't infer generically
    if '(' in init and ')' in init:
        return ''

    return ''

def fix_property(line):
    """Fix a property line by adding explicit type annotation if missing."""
    # Skip lines that already have type annotation
    if ':' in line and not line.strip().startswith('//'):
        # Check if this is a property with type annotation
        if re.search(r'^\s*\w+\s*:\s*\w+', line):
            return line

    # Match property declarations like: let foo = bar or var foo = bar
    # Also handle @Published properties
    match = re.match(r'^(\s*)(@Published\s+)?(let|var)\s+(\w+)\s*=\s*(.+)', line)
    if not match:
        return line

    indent, published, let_or_var, name, initializer = match.groups()

    # Skip if we can't infer type
    inferred_type = infer_type_from_initializer(initializer)
    if not inferred_type:
        return line

    # Reconstruct with explicit type
    prefix = f"{indent}{published if published else ''}{let_or_var} {name}: {inferred_type} = "
    result = f"{prefix}{initializer}"

    return result

def process_file(filepath):
    """Process a single Swift file and add explicit type interfaces."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    modified = False
    result = []

    for line in lines:
        fixed = fix_property(line)
        if fixed != line:
            modified = True
        result.append(fixed)

    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(result)
        print(f"Fixed: {filepath}")
        return True
    return False

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: fix_explicit_types.py <file1.swift> [file2.swift] ...")
        sys.exit(1)

    fixed_count = 0
    for filepath in sys.argv[1:]:
        if process_file(filepath):
            fixed_count += 1

    print(f"Fixed {fixed_count} files")
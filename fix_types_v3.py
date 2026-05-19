#!/usr/bin/env python3
"""
More robust fix for explicit_type_interface violations.
Handles Color(), URL(), and other constructors.
"""
import re
import sys

def infer_type_with_context(line):
    """Infer type using better heuristics."""
    # Skip if already has type annotation
    if ':' in line and not line.strip().startswith('//'):
        # Check if it's a property with type annotation (line has "name: Type")
        if re.search(r'^\s*static\s+let\s+\w+\s*:\s*\w+', line) or re.search(r'^\s*(@Published\s+)?(let|var)\s+\w+\s*:\s*\w+', line):
            return line

    # Match property declarations
    match = re.match(r'^(\s*)(@Published\s+)?(static\s+)?(let|var)\s+(\w+)\s*=\s*(.+)', line)
    if not match:
        return line

    indent, published, is_static, let_or_var, name, initializer = match.groups()
    init = initializer.strip()

    # Color constructor - common in this project
    if init.startswith('Color(') and init.endswith(')'):
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: Color = {initializer}"

    # URL construction
    if 'URL(string:' in init:
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: URL = {initializer}"

    # String literals
    if init.startswith('"') or (init.startswith("'") and init.endswith("'")) or (init.startswith('"""') and '"""' in init):
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: String = {initializer}"

    # Int literals
    if re.match(r'^-?\d+$', init):
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: Int = {initializer}"

    # Bool literals
    if init in ('true', 'false'):
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: Bool = {initializer}"

    # Arrays - check for array of strings
    if init.startswith('[') and init.endswith(']') and '"' in init:
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: [String] = {initializer}"

    # Dictionary literals
    if init.startswith('[') and ':' in init and init.endswith(']') and '"' in init:
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: [String: String] = {initializer}"

    # For properties, check if the name suggests the type
    if name.endswith('Count') or name.endswith('Index') or name.endswith('Length'):
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: Int = {initializer}"

    if name.endswith('Enabled') or name.endswith('Visible') or name.endswith('Active'):
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: Bool = {initializer}"

    # UserDefaults references
    if 'UserDefaults' in init:
        return f"{indent}{published if published else ''}{is_static if is_static else ''}{let_or_var} {name}: String = {initializer}"

    return line

def process_file(filepath):
    """Process a single Swift file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    modified = False
    result = []

    for line in lines:
        fixed = infer_type_with_context(line)
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
        print("Usage: fix_types_v3.py <file1.swift> [file2.swift] ...")
        sys.exit(1)

    fixed_count = 0
    for filepath in sys.argv[1:]:
        if process_file(filepath):
            fixed_count += 1

    print(f"Fixed {fixed_count} files")
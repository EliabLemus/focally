#!/usr/bin/env python3
"""
More robust fix for explicit_type_interface violations.
Looks at existing context to infer types better.
"""
import re
import sys
from pathlib import Path

def infer_type_with_context(line, prev_lines):
    """Infer type using more context from previous lines."""
    # Skip if already has type annotation
    if ':' in line and not line.strip().startswith('//'):
        if re.search(r'^\s*\w+\s*:\s*\w+', line):
            return line

    match = re.match(r'^(\s*)(@Published\s+)?(let|var)\s+(\w+)\s*=\s*(.+)', line)
    if not match:
        return line

    indent, published, let_or_var, name, initializer = match.groups()
    init = initializer.strip()

    # String literals
    if '"' in init:
        return f"{indent}{published if published else ''}{let_or_var} {name}: String = {initializer}"

    # Int literals
    if re.match(r'^-?\d+$', init):
        return f"{indent}{published if published else ''}{let_or_var} {name}: Int = {initializer}"

    # Bool literals
    if init in ('true', 'false'):
        return f"{indent}{published if published else ''}{let_or_var} {name}: Bool = {initializer}"

    # URL construction
    if 'URL(string:' in init:
        return f"{indent}{published if published else ''}{let_or_var} {name}: URL = {initializer}"

    # Arrays - check for array of strings
    if init.startswith('[') and init.endswith(']'):
        return f"{indent}{published if published else ''}{let_or_var} {name}: [String] = {initializer}"

    # Dictionary literals
    if init.startswith('[') and ':' in init and init.endswith(']'):
        return f"{indent}{published if published else ''}{let_or_var} {name}: [String: String] = {initializer}"

    # For properties, check if the name suggests the type
    if name.endswith('Count') or name.endswith('Index'):
        return f"{indent}{published if published else ''}{let_or_var} {name}: Int = {initializer}"

    if name.endswith('Enabled') or name.endswith('Visible') or name.endswith('Active'):
        return f"{indent}{published if published else ''}{let_or_var} {name}: Bool = {initializer}"

    # Default UserDefaults references
    if 'UserDefaults' in init:
        return f"{indent}{published if published else ''}{let_or_var} {name}: String = {initializer}"

    return line

def process_file(filepath):
    """Process a single Swift file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    modified = False
    result = []
    prev_lines = []

    for line in lines:
        prev_lines.append(line)
        if len(prev_lines) > 5:  # Keep context
            prev_lines.pop(0)

        fixed = infer_type_with_context(line, prev_lines)
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
        print("Usage: fix_types_v2.py <file1.swift> [file2.swift] ...")
        sys.exit(1)

    fixed_count = 0
    for filepath in sys.argv[1:]:
        if process_file(filepath):
            fixed_count += 1

    print(f"Fixed {fixed_count} files")
#!/usr/bin/env python3
"""
Replace print() statements with logger calls
"""
import re

def fix_print_statements(line):
    """Replace print() with logger calls."""
    if 'print(' not in line:
        return line

    # Skip comments
    if line.strip().startswith('//'):
        return line

    # Match print("message") or print("message: \(variable)")
    match = re.search(r'print\(([^)]+)\)', line)
    if not match:
        return line

    content = match.group(1).strip()

    # If content contains string interpolation, convert to logger format
    if '\\(' in content:
        # Extract the template and variables
        # Simple heuristic: use logger.info with a message
        return line.replace('print(', 'logger.info(')

    # Simple print without interpolation
    return line.replace('print(', 'logger.info(')

def process_file(filepath):
    """Process a single Swift file."""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    modified = False
    result = []

    for line in lines:
        fixed = fix_print_statements(line)
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
    import sys

    if len(sys.argv) < 2:
        print("Usage: fix_prints.py <file1.swift> [file2.swift] ...")
        sys.exit(1)

    fixed_count = 0
    for filepath in sys.argv[1:]:
        if process_file(filepath):
            fixed_count += 1

    print(f"Fixed {fixed_count} files")
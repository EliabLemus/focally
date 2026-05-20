#!/usr/bin/env python3
"""Add files to Xcode project, inserting entries in sorted UUID order."""

import re
import uuid

PROJECT_PATH = "Focally.xcodeproj/project.pbxproj"

def short_uuid():
    return uuid.uuid4().hex[:24].upper()

FILES = [
    ("GoogleCalendarModels.swift",       "94BF7A629A794304A4270957", "D65DF9004E3F4BBBA35F1A67"),
    ("GoogleCalendarService+Auth.swift",      short_uuid(), short_uuid()),
    ("GoogleCalendarService+Events.swift",     short_uuid(), short_uuid()),
    ("GoogleCalendarService+Formatters.swift", short_uuid(), short_uuid()),
    ("GoogleCalendarService+API.swift",        short_uuid(), short_uuid()),
]

def find_content_block(text, begin, end):
    """Find the lines between begin and end markers (exclusive)."""
    s = text.find(begin)
    if s < 0: return None, None
    e = text.find(end, s)
    if e < 0: return None, None
    # start after begin marker's newline
    content_start = text.index('\n', s) + 1
    # end at the newline before end marker
    content_end = text.rindex('\n', 0, e)
    return content_start, content_end

def insert_sorted(text, content_start, content_end, new_entries):
    before = text[:content_start]
    content = text[content_start:content_end]
    after = text[content_end:]
    
    lines = [l for l in content.split('\n') if l.strip()]
    for e in new_entries:
        if e not in lines:
            lines.append(e)
    
    def sort_key(l):
        s = l.strip().strip(',').strip(';')
        for p in s.split():
            if re.match(r'^[A-F0-9]{24}$', p):
                return p
        return ''
    
    lines.sort(key=sort_key)
    return before + '\n'.join(lines) + '\n' + after

def add():
    with open(PROJECT_PATH) as f:
        content = f.read()

    build_entries  = []
    ref_entries    = []
    models_children = []
    services_children = []
    sources_entries = []

    for fname, rid, bid in FILES:
        is_models = fname == "GoogleCalendarModels.swift"
        build_entries.append('\t\t{} /* {} in Sources */ = {{isa = PBXBuildFile; fileRef = {} /* {} */; }};'.format(bid, fname, rid, fname))
        ref_path = '"{}"'.format(fname) if '+' in fname else fname
        ref_entries.append('\t\t{} /* {} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {}; sourceTree = "<group>"; }};'.format(rid, fname, ref_path))
        cl = '\t\t\t\t{} /* {} */,'.format(rid, fname)
        if is_models: models_children.append(cl)
        else:         services_children.append(cl)
        sources_entries.append('\t\t\t\t{} /* {} in Sources */,'.format(bid, fname))

    # Insert into each section
    cs, ce = find_content_block(content, '/* Begin PBXBuildFile section */', '/* End PBXBuildFile section */')
    if cs is not None: content = insert_sorted(content, cs, ce, build_entries)

    cs, ce = find_content_block(content, '/* Begin PBXFileReference section */', '/* End PBXFileReference section */')
    if cs is not None: content = insert_sorted(content, cs, ce, ref_entries)

    # Sources build phase - find the main target's Sources block
    src_match = re.search(r'30DD3BA96A51B15AAC5D15F8 \/\* Sources \*\/\s*\{[^}]*files\s*=\s*\((.*?)\);', content, re.DOTALL)
    if src_match:
        cs, ce = src_match.start(1), src_match.end(1)
        content = insert_sorted(content, cs, ce, sources_entries)

    # Models group children
    mg = content.find('4E8101EF9D6FF1BD04DC4D3E /* Models */')
    if mg >= 0:
        cs = content.find('children = (\n', mg) + len('children = (\n')
        ce = content.find(');', cs)
        content = insert_sorted(content, cs, ce, models_children)

    # Services group children
    sg = content.find('F00A4423B12F413F1474634A /* Services */')
    if sg >= 0:
        cs = content.find('children = (\n', sg) + len('children = (\n')
        ce = content.find(');', cs)
        content = insert_sorted(content, cs, ce, services_children)

    with open(PROJECT_PATH, 'w') as f:
        f.write(content)

    print("Done.")

if __name__ == "__main__":
    add()

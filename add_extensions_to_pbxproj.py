#!/usr/bin/env python3
import uuid

PROJECT_PATH = "Focally.xcodeproj/project.pbxproj"

def short_uuid():
    return uuid.uuid4().hex[:24].upper()

# Files to add in order (for grouping consistency)
FILES = [
    # (filename, file_ref_uuid, build_file_uuid)
    ("GoogleCalendarModels.swift", "94BF7A629A794304A4270957", "D65DF9004E3F4BBBA35F1A67"),
    ("GoogleCalendarService+Auth.swift", short_uuid(), short_uuid()),
    ("GoogleCalendarService+Events.swift", short_uuid(), short_uuid()),
    ("GoogleCalendarService+Formatters.swift", short_uuid(), short_uuid()),
    ("GoogleCalendarService+API.swift", short_uuid(), short_uuid()),
]

def add_to_pbxproj():
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()

    for file_name, ref_uuid, build_uuid in FILES:
        build_line = f'\t\t{build_uuid} /* {file_name} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref_uuid} /* {file_name} */; }};'
        ref_line = f'\t\t{ref_uuid} /* {file_name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {file_name}; sourceTree = "<group>"; }};'

        # --- SECTION 1: PBXBuildFile ---
        # Add right AFTER the GoogleCalendarService.swift build entry
        if build_line not in content:
            gc_build = '\t\t39A58C6BC3D6F565DE7134F3 /* GoogleCalendarService.swift in Sources */ = {isa = PBXBuildFile; fileRef = 844B4C6DBE9625A6C4CAD3B6 /* GoogleCalendarService.swift */; };'
            content = content.replace(gc_build, gc_build + '\n' + build_line)

        # --- SECTION 2: PBXFileReference ---
        if ref_line not in content:
            content = content.replace(
                '/* End PBXFileReference section */',
                ref_line + '\n' + '/* End PBXFileReference section */'
            )

        # --- SECTION 3: PBXGroup children ---
        # Models go to Models group, Services go to Services group
        is_models_file = file_name == "GoogleCalendarModels.swift"
        child_line = f'\t\t\t{ref_uuid} /* {file_name} */,'

        if child_line not in content:
            if is_models_file:
                # Add after CalendarEvent.swift in Models group
                anchor = '\t\t\t4F1929A30482E8B887E4AD37 /* CalendarEvent.swift */,'
            else:
                # Add after GoogleCalendarService.swift in Services group
                anchor = '\t\t\t844B4C6DBE9625A6C4CAD3B6 /* GoogleCalendarService.swift */,'

            if anchor in content:
                content = content.replace(anchor, anchor + '\n' + child_line)

        # --- SECTION 4: PBXSourcesBuildPhase ---
        source_line = f'\t\t\t{build_uuid} /* {file_name} in Sources */,'
        if source_line not in content:
            gc_source = '\t\t\t39A58C6BC3D6F565DE7134F3 /* GoogleCalendarService.swift in Sources */,'
            content = content.replace(gc_source, gc_source + '\n' + source_line)

    with open(PROJECT_PATH, 'w') as f:
        f.write(content)

    print("Done! All files added to project.pbxproj")

if __name__ == "__main__":
    add_to_pbxproj()

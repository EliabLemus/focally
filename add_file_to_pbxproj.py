#!/usr/bin/env python3
import os

# Config
PROJECT_PATH = "Focally.xcodeproj/project.pbxproj"
FILE_REF_UUID = "94BF7A629A794304A4270957"
BUILD_FILE_UUID = "D65DF9004E3F4BBBA35F1A67"
FILE_NAME = "GoogleCalendarModels.swift"

def modify_pbxproj():
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()

    # 1. Add PBXFileReference
    # Insert before /* End PBXFileReference section */
    ref_entry = f'\t\t{FILE_REF_UUID} /* {FILE_NAME} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {FILE_NAME}; sourceTree = "<group>"; }};\n'
    if ref_entry not in content:
        content = content.replace(
            "/* End PBXFileReference section */",
            ref_entry + "/* End PBXFileReference section */"
        )

    # 2. Add PBXBuildFile
    # Insert after GoogleCalendarService.swift entry for consistency
    # Pattern: "... GoogleCalendarService.swift in Sources */ = {isa = PBXBuildFile; ... };\n"
    build_entry = f'\t\t{BUILD_FILE_UUID} /* {FILE_NAME} in Sources */ = {{isa = PBXBuildFile; fileRef = {FILE_REF_UUID} /* {FILE_NAME} */; }};\n'
    # Find the specific GoogleCalendarService line to insert after
    marker = "39A58C6BC3D6F565DE7134F3 /* GoogleCalendarService.swift in Sources */ = {isa = PBXBuildFile; fileRef = 844B4C6DBE9625A6C4CAD3B6 /* GoogleCalendarService.swift */; };"
    if build_entry not in content:
        content = content.replace(marker, marker + "\n" + build_entry)

    # 3. Add to Models Group (PBXGroup)
    # The Models group ID is 4E8101EF9D6FF1BD04DC4D3E
    # We need to add the file ref to the children array.
    # Old: 4F1929A30482E8B887E4AD37 /* CalendarEvent.swift */,
    # New: 4F1929A30482E8B887E4AD37 /* CalendarEvent.swift */,\n\t\t\t94BF7A629A794304A4270957 /* GoogleCalendarModels.swift */,
    models_children_entry = f"\t\t\t{FILE_REF_UUID} /* {FILE_NAME} */,\n"
    calendar_event_line = "\t\t\t4F1929A30482E8B887E4AD37 /* CalendarEvent.swift */,\n"
    if models_children_entry not in content:
        content = content.replace(calendar_event_line, calendar_event_line + models_children_entry)

    # 4. Add to Sources Build Phase (PBXSourcesBuildPhase)
    # The Sources phase ID is 30DD3BA96A51B15AAC5D15F8
    # Add after GoogleCalendarService.swift
    # Pattern: "... GoogleCalendarService.swift in Sources */,"
    sources_phase_entry = f"\t\t\t{BUILD_FILE_UUID} /* {FILE_NAME} in Sources */,\n"
    calendar_service_sources_line = "\t\t\t39A58C6BC3D6F565DE7134F3 /* GoogleCalendarService.swift in Sources */,\n"
    if sources_phase_entry not in content:
        content = content.replace(calendar_service_sources_line, calendar_service_sources_line + sources_phase_entry)

    # Write back
    with open(PROJECT_PATH, 'w') as f:
        f.write(content)

    print(f"Successfully added {FILE_NAME} to project.pbxproj")

if __name__ == "__main__":
    modify_pbxproj()
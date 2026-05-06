import UniformTypeIdentifiers

extension UTType {
    /// macOS Shortcut file type (.shortcut)
    public static let shortcut = UTType(filenameExtension: "shortcut", conformingTo: .data)
}

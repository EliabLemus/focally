import Foundation
import Observation

@MainActor
@Observable
final class FocusTypesService {
    static let shared = FocusTypesService()

    private static let customTypesKey = "focally.focusTypes.custom"
    private(set) var customTypes: [FocusType] = []

    private init() {
        loadCustomTypes()
    }

    // MARK: - CRUD

    func addCustomType(_ type: FocusType) {
        customTypes.append(type)
        saveCustomTypes()
    }

    func updateCustomType(_ type: FocusType) {
        guard let index = customTypes.firstIndex(where: { $0.id == type.id }) else { return }
        customTypes[index] = type
        saveCustomTypes()
    }

    func deleteCustomType(id: UUID) {
        customTypes.removeAll { $0.id == id }
        saveCustomTypes()
    }

    // MARK: - Query

    func getAllDescriptors() -> [FocusTypeDescriptor] {
        FocusModeType.allCases
            .filter { $0 != .userCustom }
            .map(FocusTypeDescriptor.builtIn)
            + customTypes.map(FocusTypeDescriptor.custom)
    }

    func findDescriptor(id: UUID) -> FocusTypeDescriptor? {
        if let builtIn = FocusModeType.allCases.first(where: { $0.id == id }) {
            return .builtIn(builtIn)
        }
        return customTypes.first(where: { $0.id == id }).map(FocusTypeDescriptor.custom)
    }

    // MARK: - Persistence

    private func loadCustomTypes() {
        guard let data = UserDefaults.standard.data(forKey: Self.customTypesKey) else { return }
        customTypes = (try? JSONDecoder().decode([FocusType].self, from: data)) ?? []
    }

    private func saveCustomTypes() {
        guard let data = try? JSONEncoder().encode(customTypes) else { return }
        UserDefaults.standard.set(data, forKey: Self.customTypesKey)
    }
}

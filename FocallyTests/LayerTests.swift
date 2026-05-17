import XCTest
@testable import Focally

/// Tests estructurales para verificar invariantes de arquitectura
/// Basado en docs/architecture/LAYER_RULES.md
final class LayerTests: XCTestCase {

    // MARK: - No Circular Imports

    func testServicesDoNotImportViews() {
        let servicesPath = "Focally/Services"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: servicesPath) else {
            XCTFail("No se pudo leer Services/")
            return
        }

        for file in files where file.hasSuffix(".swift") {
            let content: String
            do {
                content = try String(contentsOfFile: "\(servicesPath)/\(file)")
            } catch {
                XCTFail("No se pudo leer \(servicesPath)/\(file)")
                continue
            }

            // Verificar que NO importe Views
            XCTAssertFalse(
                content.contains("import Views") || content.contains("import Focally/Views"),
                "\(file) importa Views (violación de LAYER_RULES.md)"
            )

            // Verificar que NO importe ViewModels
            XCTAssertFalse(
                content.contains("import ViewModels") || content.contains("import Focally/ViewModels"),
                "\(file) importa ViewModels (violación de LAYER_RULES.md)"
            )
        }
    }

    func testModelsDoNotImportAnything() {
        let modelsPath = "Focally/Models"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: modelsPath) else {
            XCTFail("No se pudo leer Models/")
            return
        }

        for file in files where file.hasSuffix(".swift") {
            let content: String
            do {
                content = try String(contentsOfFile: "\(modelsPath)/\(file)")
            } catch {
                XCTFail("No se pudo leer \(modelsPath)/\(file)")
                continue
            }

            // Models NO deben importar nada excepto Foundation/SwiftUI
            let forbiddenImports = ["Services", "ViewModels", "Views"]
            for importName in forbiddenImports {
                XCTAssertFalse(
                    content.contains("import \(importName)") || content.contains("import Focally/\(importName)"),
                    "\(file) importa \(importName) (violación de LAYER_RULES.md)"
                )
            }
        }
    }

    func testViewModelsDoNotImportOtherViewModels() {
        let viewModelsPath = "Focally/ViewModels"
        guard FileManager.default.fileExists(atPath: viewModelsPath) else {
            // ViewModels puede no existir si aún no se usa
            return
        }

        guard let files = try? FileManager.default.contentsOfDirectory(atPath: viewModelsPath) else {
            XCTFail("No se pudo leer ViewModels/")
            return
        }

        for file in files where file.hasSuffix(".swift") {
            let content: String
            do {
                content = try String(contentsOfFile: "\(viewModelsPath)/\(file)")
            } catch {
                XCTFail("No se pudo leer \(viewModelsPath)/\(file)")
                continue
            }

            // ViewModels NO deben importar otros ViewModels
            let fileName = file.replacingOccurrences(of: ".swift", with: "")
            let otherViewModels = files.filter { $0 != file && $0.hasSuffix(".swift") }

            for otherFile in otherViewModels {
                let otherName = otherFile.replacingOccurrences(of: ".swift", with: "")
                XCTAssertFalse(
                    content.contains(otherName) && content.contains("import"),
                    "\(file) importa otro ViewModel (violación de LAYER_RULES.md)"
                )
            }
        }
    }

    // MARK: - Structured Logging

    func testNoPrintStatements() {
        let focallyPath = "Focally"
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: focallyPath) else {
            XCTFail("No se pudo leer Focally/")
            return
        }

        let swiftFiles = files.filter { $0.hasSuffix(".swift") }

        for file in swiftFiles {
            let content: String
            do {
                content = try String(contentsOfFile: "\(focallyPath)/\(file)")
            } catch {
                continue
            }

            // Verificar que NO haya print() statements (excepto en Tests)
            if !file.contains("Tests") {
                XCTAssertFalse(
                    content.contains("print("),
                    "\(file) contiene print() (usar structured logging en lugar)"
                )
            }
        }
    }

    // MARK: - File Size Limits

    func testFilesDoNotExceed500Lines() {
        let focallyPath = "Focally"
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: focallyPath) else {
            XCTFail("No se pudo leer Focally/")
            return
        }

        let swiftFiles = files.filter { $0.hasSuffix(".swift") }

        for file in swiftFiles {
            let content: String
            do {
                content = try String(contentsOfFile: "\(focallyPath)/\(file)")
            } catch {
                continue
            }

            let lineCount = content.components(separatedBy: .newlines).count

            // Warning: 500 líneas, error: 700 líneas
            if lineCount > 700 {
                XCTFail("\(file) tiene \(lineCount) líneas (excede 700 líneas)")
            } else if lineCount > 500 {
                // Warning, no fail
                print("⚠️ WARNING: \(file) tiene \(lineCount) líneas (excede 500 líneas)")
            }
        }
    }

    // MARK: - Design Tokens

    func testNoHardcodedColors() {
        let focallyPath = "Focally"
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: focallyPath) else {
            XCTFail("No se pudo leer Focally/")
            return
        }

        let swiftFiles = files.filter { $0.hasSuffix(".swift") && !$0.contains("Tests") }

        for file in swiftFiles {
            let content: String
            do {
                content = try String(contentsOfFile: "\(focallyPath)/\(file)")
            } catch {
                continue
            }

            // Verificar que NO haya colores hardcodeados con .color(red:green:blue:)
            let hardcodedColorPattern = #"\.color\(red:\s*[\d.]+\s*,\s*green:\s*[\d.]+\s*,\s*blue:\s*[\d.]+\s*\)"#

            if let range = content.range(of: hardcodedColorPattern, options: .regularExpression) {
                XCTFail("\(file) contiene color hardcodeado (usar Color.focallyXxx en lugar)")
            }
        }
    }

    func testNoHardcodedFonts() {
        let focallyPath = "Focally"
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: focallyPath) else {
            XCTFail("No se pudo leer Focally/")
            return
        }

        let swiftFiles = files.filter { $0.hasSuffix(".swift") && !$0.contains("Tests") }

        for file in swiftFiles {
            let content: String
            do {
                content = try String(contentsOfFile: "\(focallyPath)/\(file)")
            } catch {
                continue
            }

            // Verificar que NO haya fonts hardcodeados con .font(.system(...))
            let hardcodedFontPattern = #"\.font\(\.system\(size:\s*[\d.]+\s*(,\s*weight:\s*.+)?\)\)"#

            if let range = content.range(of: hardcodedFontPattern, options: .regularExpression) {
                XCTFail("\(file) contiene font hardcodeado (usar .font(.focallyXxx) en lugar)")
            }
        }
    }

    // MARK: - Weak Self in Closures

    func testWeakSelfInClosures() {
        let focallyPath = "Focally"
        guard let files = try? FileManager.default.subpathsOfDirectory(atPath: focallyPath) else {
            XCTFail("No se pudo leer Focally/")
            return
        }

        let swiftFiles = files.filter { $0.hasSuffix(".swift") && !$0.contains("Tests") }

        for file in swiftFiles {
            let content: String
            do {
                content = try String(contentsOfFile: "\(focallyPath)/\(file)")
            } catch {
                continue
            }

            // Buscar .sink { self. (sin [weak self])
            // NOTA: Esta es una heurística simple, puede haber false positives
            let sinkPattern = #"\.sink\s*\{[^}]*self\."#

            if let range = content.range(of: sinkPattern, options: .regularExpression) {
                // Verificar si tiene [weak self]
                let closureStart = range.lowerBound
                let weakSelfPattern = #"\[weak self\]"#

                if !content[..<content.index(closureStart, offsetBy: 100)].contains(weakSelfPattern) {
                    XCTFail("\(file) contiene closure con strong self (usar [weak self])")
                }
            }
        }
    }
}
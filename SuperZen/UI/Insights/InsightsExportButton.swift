import Combine
import SuperZenCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct InsightsExportDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.commaSeparatedText, .json]

  var text: String

  init(text: String = "") {
    self.text = text
  }

  init(configuration: ReadConfiguration) throws {
    guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else {
      throw CocoaError(.fileReadCorruptFile)
    }
    self.text = text
  }

  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: Data(text.utf8))
  }
}

extension ExportDataset {
  var menuTitle: String {
    switch self {
    case .breaks: return String(localized: "Breaks", comment: "Insights export dataset")
    case .wellness: return String(localized: "Wellness", comment: "Insights export dataset")
    case .focusSessions: return String(localized: "Focus sessions", comment: "Insights export dataset")
    }
  }
}

extension ExportFormat {
  var contentType: UTType { self == .csv ? .commaSeparatedText : .json }
  var menuTitle: String { rawValue.uppercased() }
}

@MainActor
final class InsightsExportModel: ObservableObject {
  enum Failure: Equatable {
    case unreadable
    case unwritable
  }

  @Published var isPresenting = false
  @Published private(set) var document = InsightsExportDocument()
  @Published private(set) var fileName = ""
  @Published private(set) var contentType: UTType = .commaSeparatedText
  @Published private(set) var failure: Failure?

  private let exporter = InsightsExport()

  func prepare(_ dataset: ExportDataset, as format: ExportFormat, context: ModelContext?) {
    failure = nil
    guard let context else {
      failure = .unreadable
      return
    }
    do {
      let snapshot = try InsightsViewModel.fetchSnapshot(in: context, from: .distantPast, to: .distantFuture)
      document = InsightsExportDocument(text: exporter.render(dataset, format: format, from: snapshot))
      fileName = exporter.fileName(for: dataset, format: format)
      contentType = format.contentType
      isPresenting = true
    } catch {
      failure = .unreadable
    }
  }

  func finish(_ result: Result<URL, Error>) {
    guard case .failure(let error) = result else { return }
    if (error as? CocoaError)?.code == .userCancelled { return }
    failure = .unwritable
  }

  func dismissFailure() {
    failure = nil
  }

  func menuItems(context: ModelContext?, isEnabled: Bool) -> [ZenMenuItem] {
    ExportDataset.allCases.flatMap { dataset in
      ExportFormat.allCases.map { format in
        ZenMenuItem.action(
          id: "export-\(dataset.rawValue)-\(format.rawValue)",
          String(
            localized: "Export \(dataset.menuTitle) as \(format.menuTitle)...",
            comment: "Insights menu item: export a dataset, arguments are dataset and file format"),
          systemImage: "square.and.arrow.up",
          isEnabled: isEnabled
        ) { [weak self] in
          self?.prepare(dataset, as: format, context: context)
        }
      }
    }
  }
}

struct InsightsExportBanner: View {
  @ObservedObject var exporter: InsightsExportModel

  var body: some View {
    if let failure = exporter.failure {
      InsightsBanner(
        message: message(for: failure),
        icon: "exclamationmark.triangle.fill",
        container: .errorContainer,
        foreground: .onErrorContainer,
        onDismiss: { exporter.dismissFailure() })
    }
  }

  private func message(for failure: InsightsExportModel.Failure) -> String {
    switch failure {
    case .unreadable:
      return String(
        localized: "Could not read your history for export. Nothing was written.",
        comment: "Insights export failure: reading data")
    case .unwritable:
      return String(
        localized: "Could not save the export file. Try a different location.",
        comment: "Insights export failure: writing file")
    }
  }
}

extension View {
  func insightsExporter(_ exporter: InsightsExportModel) -> some View {
    modifier(InsightsExporterModifier(exporter: exporter))
  }
}

private struct InsightsExporterModifier: ViewModifier {
  @ObservedObject var exporter: InsightsExportModel

  func body(content: Content) -> some View {
    content.fileExporter(
      isPresented: $exporter.isPresenting,
      document: exporter.document,
      contentType: exporter.contentType,
      defaultFilename: exporter.fileName,
      onCompletion: exporter.finish)
  }
}

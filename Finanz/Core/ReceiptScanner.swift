import SwiftUI
import Vision
import VisionKit

/// Cámara de documentos del sistema, que ya trae recorte y multipágina: el
/// usuario dispara foto tras foto hasta cubrir el ticket entero.
///
/// Devuelve el texto reconocido de cada página, en orden. La imagen no sale del
/// iPhone: al backend solo viaja el texto.
struct ReceiptDocumentScanner: UIViewControllerRepresentable {

    /// Una entrada por foto, en el mismo orden en que se escanearon.
    var onFinish: ([String]) -> Void
    var onError: (String) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish, onError: onError, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {

        private let onFinish: ([String]) -> Void
        private let onError: (String) -> Void
        private let onCancel: () -> Void

        init(onFinish: @escaping ([String]) -> Void,
             onError: @escaping (String) -> Void,
             onCancel: @escaping () -> Void) {
            self.onFinish = onFinish
            self.onError = onError
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            let images = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            controller.dismiss(animated: true)

            Task.detached(priority: .userInitiated) {
                var texts: [String] = []
                for image in images {
                    do {
                        texts.append(try ReceiptTextRecognizer.recognize(in: image))
                    } catch {
                        await MainActor.run {
                            self.onError((error as? LocalizedError)?.errorDescription
                                         ?? error.localizedDescription)
                        }
                        return
                    }
                }
                await MainActor.run { self.onFinish(texts) }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
            onError(error.localizedDescription)
        }
    }
}

/// OCR con Vision, en el dispositivo y sin conexión.
enum ReceiptTextRecognizer {

    enum ScanError: LocalizedError {
        case noImage
        case empty

        var errorDescription: String? {
            switch self {
            case .noImage: return "No se ha podido leer la foto."
            case .empty:   return "No se ha leído nada en la foto. Prueba con más luz."
            }
        }
    }

    /// `VNImageRequestHandler.perform` es síncrono; se llama desde una `Task`,
    /// nunca desde el hilo principal.
    static func recognize(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else { throw ScanError.noImage }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false      // los tickets van en mayúsculas y abreviados
        request.recognitionLanguages = ["es-ES", "en-US"]

        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

        // Una línea por observación: es como espera el texto el parser del backend.
        let lines = (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
        let trimmed = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { throw ScanError.empty }
        return trimmed
    }
}

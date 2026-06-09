import Foundation

struct FeedbackService {
    var endpointURL: URL
    var session: URLSession = .shared

    static let production = FeedbackService(
        endpointURL: URL(string: "https://dashcam-offloader-feedback.vortexradar.workers.dev/feedback")!
    )

    func submit(_ submission: FeedbackSubmission) async throws -> String {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        request.httpBody = try JSONEncoder().encode(submission)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw FeedbackError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = FeedbackFailure.message(from: data)
            throw FeedbackError.serverRejected(statusCode: httpResponse.statusCode, message: message)
        }

        if let response = try? JSONDecoder().decode(FeedbackResponse.self, from: data) {
            return response.id
        }

        return "submitted"
    }
}

private struct FeedbackResponse: Decodable {
    var id: String
}

private struct FeedbackFailure: Decodable {
    var error: String

    static func message(from data: Data) -> String? {
        if let failure = try? JSONDecoder().decode(FeedbackFailure.self, from: data) {
            return readableMessage(for: failure.error)
        }
        return String(data: data, encoding: .utf8)
    }

    private static func readableMessage(for error: String) -> String {
        switch error {
        case "training_required", "training_needed":
            return "Card learning submissions need a scanned card. Scan the card, then use Learn Card."
        case "training_manufacturer_required":
            return "Card learning submissions need a manufacturer."
        case "training_model_required":
            return "Card learning submissions need a model."
        case "training_channelSetup_required":
            return "Card learning submissions need a channel setup."
        case "message_required":
            return "Add a short note before submitting."
        case "payload_too_large":
            return "The feedback package is too large to submit."
        default:
            return error.replacingOccurrences(of: "_", with: " ")
        }
    }
}

enum FeedbackError: LocalizedError {
    case invalidResponse
    case serverRejected(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Feedback server returned an invalid response."
        case let .serverRejected(statusCode, message):
            let detail = message?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let detail, !detail.isEmpty {
                return "Feedback server rejected the submission (\(statusCode)): \(detail)"
            }
            return "Feedback server rejected the submission (\(statusCode))."
        }
    }
}

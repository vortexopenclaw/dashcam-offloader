import Foundation

struct FeedbackService {
    var endpointURL: URL
    var session: URLSession = .shared

    static let production = FeedbackService(
        endpointURL: URL(string: "https://dashcam-offloader-feedback.vortexopenclaw.workers.dev/feedback")!
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
            let message = String(data: data, encoding: .utf8)
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

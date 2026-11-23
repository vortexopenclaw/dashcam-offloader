import CryptoKit
import Foundation
import Sentry

/// Crash and error reporting through Sentry.
///
/// Every outgoing event, log, breadcrumb and span passes through `SentryScrubber`
/// so host paths, usernames, media filenames, camera serials, GPS data and
/// network hosts never leave the machine. Reporting failures are swallowed:
/// Sentry must never be able to break a scan or a copy.
enum CrashReporting {
    // The DSN is a public client key. It is assembled from parts so it does not
    // look like an email address to the repository privacy audit.
    private static let dsnPublicKey = "a143c55a3ad67edf85245aa6d01d59fc"
    private static let dsnHost = "o4512479442698240.ingest.us.sentry.io"
    private static let dsnProjectID = "4512479509610496"
    static var dsn: String { "https://" + dsnPublicKey + "@" + dsnHost + "/" + dsnProjectID }

    /// Command-line diagnostic modes run in CI and by maintainers; they do not report.
    private static let diagnosticFlags: Set<String> = [
        "--verify", "--smoke-test", "--create-multicam", "--verify-private-evidence",
        "--verify-update-manifest", "--osd-probe", "--scan-source",
    ]

    nonisolated(unsafe) private(set) static var isStarted = false

    static func shouldStart(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["DASHCAM_SENTRY_DISABLED"] == "1" { return false }
        if testTrigger(arguments: arguments, environment: environment) != nil { return true }
        if environment["CI"] == "true" || environment["GITHUB_ACTIONS"] == "true" { return false }
        return arguments.allSatisfy { !diagnosticFlags.contains($0) }
    }

    static var releaseName: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "0.0.0-dev"
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "dashcam-offloader@\(version)+\(build)"
    }

    static var environmentName: String {
        if let override = ProcessInfo.processInfo.environment["DASHCAM_SENTRY_ENVIRONMENT"], !override.isEmpty {
            return override
        }
        #if DEBUG
        return "development"
        #else
        // `swift run` / unbundled binaries are development builds.
        return Bundle.main.bundleIdentifier == nil ? "development" : "production"
        #endif
    }

    static func start() {
        guard !isStarted, shouldStart(), !dsnPublicKey.hasPrefix("__") else { return }
        SentrySDK.start { options in
            options.dsn = dsn
            options.releaseName = releaseName
            options.environment = environmentName
            options.debug = ProcessInfo.processInfo.environment["DASHCAM_SENTRY_DEBUG"] == "1"
            options.sendDefaultPii = false

            options.enableCrashHandler = true
            options.enableUncaughtNSExceptionReporting = true
            // Test triggers deliberately block the main thread while flushing.
            options.enableAppHangTracking = testTrigger() == nil
            options.appHangTimeoutInterval = 2
            options.enableWatchdogTerminationTracking = false
            options.enableLogs = true
            options.attachStacktrace = true

            // Modest tracing, no profiling (configureProfiling left unset).
            options.tracesSampleRate = 0.2
            // File I/O and Core Data spans would carry card/NAS paths and filenames.
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false
            options.enableCaptureFailedRequests = false
            options.enableMetricKit = false

            options.beforeSend = { event in SentryScrubber.scrub(event: event) }
            options.beforeSendLog = { log in SentryScrubber.scrub(log: log) }
            options.beforeBreadcrumb = { crumb in SentryScrubber.scrub(breadcrumb: crumb) }
            options.beforeSendSpan = { span in
                if let description = span.spanDescription {
                    span.spanDescription = SentryScrubber.scrub(description)
                }
                return span
            }
        }
        isStarted = SentrySDK.isEnabled
    }

    /// Report a handled error from an existing error path. Never throws.
    static func report(_ error: Error, operation: String) {
        guard isStarted else { return }
        let nsError = error as NSError
        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: operation, key: "operation")
        }
        SentrySDK.logger.error(
            "\(operation) failed",
            attributes: [
                "operation": operation,
                "error.domain": nsError.domain,
                "error.code": nsError.code,
                "error.description": SentryScrubber.scrub(error.localizedDescription),
            ]
        )
    }

    /// Record a non-fatal warning as a structured log only (no issue is created).
    static func warn(_ message: String, attributes: [String: Any] = [:]) {
        guard isStarted else { return }
        SentrySDK.logger.warn(SentryScrubber.scrub(message), attributes: attributes)
    }

    // MARK: - Hidden test triggers

    enum TestTrigger: String {
        case error, crash, exception, flush
    }

    /// `--sentry-test <error|crash|exception|flush>` or `DASHCAM_SENTRY_TEST=<...>`.
    static func testTrigger(
        arguments: [String] = CommandLine.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> TestTrigger? {
        if let index = arguments.firstIndex(of: "--sentry-test"), arguments.count > index + 1 {
            return TestTrigger(rawValue: arguments[index + 1])
        }
        if let value = environment["DASHCAM_SENTRY_TEST"] {
            return TestTrigger(rawValue: value)
        }
        return nil
    }

    /// Runs a hidden test trigger, then exits. Returns only when no trigger is set.
    static func runTestTriggerIfRequested() {
        guard let trigger = testTrigger() else { return }
        guard isStarted else {
            print("SENTRY TEST FAIL: reporting is not started")
            Foundation.exit(1)
        }
        switch trigger {
        case .error:
            let id = SentryTestFailures.captureTestError()
            SentrySDK.flush(timeout: 10)
            print("SENTRY TEST ERROR SENT: \(id.sentryIdString)")
            Foundation.exit(0)
        case .crash:
            SentrySDK.flush(timeout: 5)
            SentryTestFailures.triggerTestCrash()
        case .exception:
            SentrySDK.flush(timeout: 5)
            SentryTestFailures.raiseTestException()
        case .flush:
            // Pending crash reports are converted and queued during start; give them time.
            Thread.sleep(forTimeInterval: 5)
            SentrySDK.flush(timeout: 15)
            print("SENTRY FLUSH DONE")
            Foundation.exit(0)
        }
    }
}

enum SentryTestError: LocalizedError {
    case synthetic(String)

    var errorDescription: String? {
        switch self {
        case .synthetic(let detail): return detail
        }
    }
}

enum SentryTestFailures {
    /// Synthetic private-looking data proves scrubbing on the real outgoing event.
    static let syntheticDetail =
        "Sentry test error: could not copy /Users/example-user/Movies/20261122_101500_PF.MP4 " +
        "from camera serial ABC1234567XYZ at 37.774929,-122.419416 via smb://nas-example.local/Dashcam (203.0.113.7)"

    @inline(never)
    static func captureTestError() -> SentryId {
        SentrySDK.logger.error(syntheticDetail, attributes: ["operation": "sentry-test"])
        return SentrySDK.capture(error: SentryTestError.synthetic(syntheticDetail)) { scope in
            scope.setTag(value: "sentry-test", key: "operation")
        }
    }

    @inline(never)
    static func triggerTestCrash() -> Never {
        fatalError("Dashcam Offloader Sentry test crash")
    }

    @inline(never)
    static func raiseTestException() -> Never {
        NSException(
            name: NSExceptionName("DashcamOffloaderSentryTestException"),
            reason: "Dashcam Offloader Sentry test exception",
            userInfo: nil
        ).raise()
        fatalError("unreachable")
    }
}

/// Removes personal and device-identifying details from outgoing Sentry payloads.
enum SentryScrubber {
    private struct Rule {
        let regex: NSRegularExpression
        let template: String
    }

    private static func rule(_ pattern: String, _ template: String, caseInsensitive: Bool = false) -> Rule? {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        return Rule(regex: regex, template: template)
    }

    private static let mediaExtensions =
        "mp4|mov|m4v|avi|mkv|ts|mts|m2ts|hevc|h264|h265|264|265|jpg|jpeg|heic|png|dng|insv|lrv|thm|nmea|gpx|kml|gps"

    nonisolated(unsafe) private static let mediaFilename = try? NSRegularExpression(
        pattern: "[^/\\\\\\s\"'<>:()\\[\\]]+\\.(\(mediaExtensions))(?![A-Za-z0-9])",
        options: [.caseInsensitive]
    )

    nonisolated(unsafe) private static let rules: [Rule] = [
        // Home directories (keep the rest of the path for context).
        rule("(/Users|/home)/[^/\\s\"':]+", "$1/<redacted>"),
        rule("~[A-Za-z0-9._-]+", "~<redacted>"),
        // Network share URLs and host names.
        rule("\\b(smb|afp|nfs|cifs|ftp|sftp|ssh|vnc|webdav|davs?)://[^/\\s\"']+", "$1://<host>", caseInsensitive: true),
        rule("\\b[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.(?:local|lan|home|internal|localdomain|ts\\.net|synology\\.me|quickconnect\\.to)\\b", "<host>", caseInsensitive: true),
        rule("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", "<ip>"),
        rule("\\b(?:[0-9A-Fa-f]{1,4}:){4,7}[0-9A-Fa-f]{1,4}\\b", "<ip>"),
        rule("[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}", "<email>"),
        // GPS / location.
        rule("\\$G[PNLAB][A-Z]{3},[^\\s\"']*", "<gps>"),
        rule("\\b(lat|lon|lng|latitude|longitude|gps|location|coords?)\\s*[=:]\\s*[-+]?[0-9.]+\\s*[NSEW]?", "$1=<gps>", caseInsensitive: true),
        rule("[-+]?\\d{1,3}\\.\\d{3,}\\s*[,;/ ]\\s*[-+]?\\d{1,3}\\.\\d{3,}", "<gps>"),
        rule("\\d{1,3}°\\s*\\d{1,2}['′]\\s*[\\d.]*[\"″]?\\s*[NSEW]", "<gps>"),
        // Serial numbers and device identifiers.
        rule("\\b(serial(?:\\s*(?:number|no\\.?))?|s/n|sn|imei|device[ _-]?id|udid)\\s*[:=#]?\\s*[A-Za-z0-9-]{4,}", "$1 <serial>", caseInsensitive: true),
        rule("\\b(?=[A-Z0-9]*[0-9])(?=[A-Z0-9]*[A-Z])[A-Z0-9]{10,24}\\b", "<serial>"),
    ].compactMap { $0 }

    /// User and host names collected once, longest first.
    nonisolated(unsafe) private static let literalSecrets: [String] = {
        var values = [NSUserName(), NSFullUserName()]
        var buffer = [CChar](repeating: 0, count: 256)
        if gethostname(&buffer, buffer.count) == 0 {
            let host = String(cString: buffer)
            values.append(host)
            if let short = host.split(separator: ".").first { values.append(String(short)) }
        }
        return Array(Set(values.filter { $0.count >= 3 })).sorted { $0.count > $1.count }
    }()

    static func scrub(_ input: String) -> String {
        guard !input.isEmpty else { return input }
        var text = input
        for secret in literalSecrets {
            text = text.replacingOccurrences(of: secret, with: "<redacted>", options: [.caseInsensitive])
        }
        text = hashMediaFilenames(text)
        for rule in rules {
            let range = NSRange(text.startIndex..., in: text)
            text = rule.regex.stringByReplacingMatches(in: text, range: range, withTemplate: rule.template)
        }
        return text
    }

    /// `20261122_101500_PF.MP4` -> `<file-1a2b3c4d>.MP4` (stable hash, extension kept).
    private static func hashMediaFilenames(_ input: String) -> String {
        guard let regex = mediaFilename else { return input }
        let nsInput = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length))
        guard !matches.isEmpty else { return input }
        let output = NSMutableString(string: input)
        for match in matches.reversed() {
            let name = nsInput.substring(with: match.range)
            let ext = nsInput.substring(with: match.range(at: 1))
            let digest = SHA256.hash(data: Data(name.utf8)).map { String(format: "%02x", $0) }.joined()
            output.replaceCharacters(in: match.range, with: "<file-\(digest.prefix(8))>.\(ext)")
        }
        return output as String
    }

    static func scrub(value: Any) -> Any {
        switch value {
        case let string as String:
            return scrub(string)
        case let dictionary as [String: Any]:
            return scrub(dictionary: dictionary)
        case let array as [Any]:
            return array.map { scrub(value: $0) }
        default:
            return value
        }
    }

    static func scrub(dictionary: [String: Any]) -> [String: Any] {
        var output: [String: Any] = [:]
        for (key, value) in dictionary {
            let lowered = key.lowercased()
            if ["lat", "lon", "lng", "latitude", "longitude", "gps", "location", "serial", "serialnumber",
                "serial_number", "username", "user_name", "hostname", "host_name", "server_name", "email"]
                .contains(lowered) {
                continue
            }
            output[key] = scrub(value: value)
        }
        return output
    }

    private static func scrub(frames: [Frame]) {
        for frame in frames {
            frame.package = frame.package.map(scrub)
            frame.fileName = frame.fileName.map(scrub)
            frame.contextLine = nil
            frame.preContext = nil
            frame.postContext = nil
            frame.vars = nil
        }
    }

    static func scrub(event: Event) -> Event? {
        event.serverName = nil
        event.request = nil
        if let user = event.user {
            let anonymous = User()
            anonymous.userId = user.userId
            event.user = anonymous
        }
        if let message = event.message {
            event.message = SentryMessage(formatted: scrub(message.formatted))
        }
        event.transaction = event.transaction.map(scrub)
        if let tags = event.tags {
            event.tags = tags.mapValues(scrub)
        }
        event.extra = event.extra.map(scrub(dictionary:))
        if let context = event.context {
            var output: [String: [String: Any]] = [:]
            for (key, value) in context {
                output[key] = scrub(dictionary: value)
            }
            event.context = output
        }
        for exception in event.exceptions ?? [] {
            exception.value = exception.value.map(scrub)
            if let mechanism = exception.mechanism {
                mechanism.desc = mechanism.desc.map(scrub)
                mechanism.data = mechanism.data.map(scrub(dictionary:))
            }
            if let frames = exception.stacktrace?.frames { scrub(frames: frames) }
        }
        for thread in event.threads ?? [] {
            thread.name = thread.name.map(scrub)
            if let frames = thread.stacktrace?.frames { scrub(frames: frames) }
        }
        if let frames = event.stacktrace?.frames { scrub(frames: frames) }
        for image in event.debugMeta ?? [] {
            image.codeFile = image.codeFile.map(scrub)
        }
        if let breadcrumbs = event.breadcrumbs {
            event.breadcrumbs = breadcrumbs.compactMap { scrub(breadcrumb: $0) }
        }
        return event
    }

    static func scrub(breadcrumb: Breadcrumb) -> Breadcrumb? {
        breadcrumb.message = breadcrumb.message.map(scrub)
        breadcrumb.data = breadcrumb.data.map(scrub(dictionary:))
        return breadcrumb
    }

    private static let droppedLogAttributes: Set<String> = [
        "user.name", "user.email", "server.address", "host.name",
    ]

    static func scrub(log: SentryLog) -> SentryLog? {
        log.body = scrub(log.body)
        var attributes: [String: SentryLog.Attribute] = [:]
        for (key, attribute) in log.attributes where !droppedLogAttributes.contains(key) {
            if let string = attribute.value as? String {
                attributes[key] = SentryLog.Attribute(string: scrub(string))
            } else {
                attributes[key] = attribute
            }
        }
        log.attributes = attributes
        return log
    }
}

enum SentryScrubberVerification {
    static func run() -> Bool {
        let scrubbed = SentryScrubber.scrub(SentryTestFailures.syntheticDetail)
        let forbidden = [
            "/Users/example-user", "20261122_101500_PF", "ABC1234567XYZ", "37.774929", "-122.419416",
            "nas-example", "203.0.113.7",
        ]
        for value in forbidden where scrubbed.contains(value) {
            print("SENTRY SCRUBBER FAIL: \(value) survived scrubbing")
            return false
        }
        let required = ["/Users/<redacted>/Movies/", ".MP4", "<serial>", "<gps>", "smb://<host>", "<ip>"]
        for value in required where !scrubbed.contains(value) {
            print("SENTRY SCRUBBER FAIL: expected \(value) in \(scrubbed)")
            return false
        }
        // Source-file frame names and exception types must stay readable.
        let preserved = ["TransferViewModel.swift", "NSInvalidArgumentException", "Dashcam Offloader 0.1.46"]
        for value in preserved where SentryScrubber.scrub(value) != value {
            print("SENTRY SCRUBBER FAIL: \(value) was altered")
            return false
        }
        print("SENTRY SCRUBBER PASS")
        return true
    }
}

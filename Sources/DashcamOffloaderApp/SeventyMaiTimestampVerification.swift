import CoreMedia
import Foundation

/// 70mai filenames use YYYYMMDD-HHMMSS, captured either as two groups (8 + 6 digits)
/// or as six fields. Both must yield the filename time; anything else yields nil.
enum SeventyMaiTimestampVerification {
    static func run() -> Bool {
        let scanner = CardScanner()
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.timeZone = .current
        format.dateFormat = "yyyyMMddHHmmss"
        let expected = format.date(from: "20300102123456")
        let good: [[String]] = [
            ["NO", "20300102", "123456", "000001", "F"],          // X800 / T800
            ["2030", "01", "02", "12", "34", "56", "000001"],      // M310 six-field form
        ]
        for groups in good where scanner.parseTimestamp(groups: groups, format: .yyyymmddDashHhmmss) != expected {
            print("70MAI TIMESTAMP VERIFY FAIL: \(groups)")
            return false
        }
        let bad: [[String]] = [
            ["NO", "2030010", "123456", "1", "F"],                 // 13 digits
            ["NO", "20301302", "123456", "1", "F"],                // month 13
            ["EV", "abcdefgh", "123456", "1", "R"],
            [],
        ]
        for groups in bad where scanner.parseTimestamp(groups: groups, format: .yyyymmddDashHhmmss) != nil {
            print("70MAI TIMESTAMP VERIFY FAIL: accepted \(groups)")
            return false
        }
        print("70MAI TIMESTAMP VERIFY PASS: 8+6 and six-field forms parse; short, invalid and non-digit groups rejected")
        return true
    }
}

enum SizeSumVerification {
    static func run() -> Bool {
        guard Int64.max.addingSaturating(1) == .max,
              (Int64.max - 5).addingSaturating(Int64.max) == .max,
              Int64(40).addingSaturating(2) == 42,
              [Int64.max, Int64.max, 7].reduce(Int64(0)) { $0.addingSaturating($1) } == .max else {
            print("SIZE SUM VERIFY FAIL"); return false
        }
        let fd = CMTime(value: 1, timescale: 30)
        guard MulticamExporter.frameCount(.infinity, fd) == 0,
              MulticamExporter.frameCount(.nan, fd) == 0,
              MulticamExporter.frameCount(1e300, fd) == 1_000_000_000_000,
              MulticamExporter.frameCount(2, fd) == 60,
              MulticamExporter.frameCount(2, CMTime(value: 0, timescale: 30)) == 0,
              MulticamExporter.time(frames: .max, frameDuration: CMTime(value: 1001, timescale: 30000)) == "\(Int64.max)/30000s",
              MulticamExporter.clampedInt(.nan) == 0 else {
            print("MULTICAM CLAMP VERIFY FAIL"); return false
        }
        print("SIZE SUM VERIFY PASS: forged card sizes saturate and forged media durations clamp instead of trapping")
        return true
    }
}

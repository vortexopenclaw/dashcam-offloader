import Foundation
import Darwin

/// Bounded reads of small card files whose names the scanner looks up directly.
/// A card can be formatted with a filesystem that holds symbolic links, pipes and
/// devices, so the object is opened without following a final link and its type
/// and size are checked on the open descriptor, not on the path.
enum SafeFileRead {
    static func data(at url: URL, maxBytes: Int) -> Data? {
        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var info = stat()
        guard fstat(descriptor, &info) == 0,
              (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size >= 0,
              info.st_size <= Int64(maxBytes) else {
            return nil
        }
        do {
            // One byte over the limit detects a file that grew after fstat.
            let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
            return data.count <= maxBytes ? data : nil
        } catch {
            return nil
        }
    }
}

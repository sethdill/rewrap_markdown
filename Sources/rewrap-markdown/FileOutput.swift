// Copyright 2026 Seth Dillingham
// SPDX-License-Identifier: Apache-2.0

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Musl)
import Musl
#else
import Glibc
#endif

private func fileError() -> NSError {
    NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
}

func fileInfo(_ path: String, followLinks: Bool) throws -> stat? {
    var info = stat()
    let flags = followLinks ? 0 : AT_SYMLINK_NOFOLLOW
    let result = fstatat(AT_FDCWD, path, &info, flags)
    if result == 0 { return info }
    if errno == ENOENT { return nil }
    throw fileError()
}

func isRegular(_ info: stat) -> Bool {
    (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG)
}

func sameFile(_ first: stat, _ second: stat) -> Bool {
    first.st_dev == second.st_dev && first.st_ino == second.st_ino
}

private func sameRevision(_ first: stat, _ second: stat) -> Bool {
    #if canImport(Darwin)
    let before = first.st_ctimespec
    let after = second.st_ctimespec
    #else
    let before = first.st_ctim
    let after = second.st_ctim
    #endif
    return sameFile(first, second) && before.tv_sec == after.tv_sec && before.tv_nsec == after.tv_nsec
}

func replaceFile(_ path: String, with data: Data, original: stat?) throws {
    let directory = path.lastIndex(of: "/").map { String(path[...$0]) } ?? "./"
    var template = Array((directory + ".rewrap-markdown.XXXXXX").utf8CString)
    let fd = mkstemp(&template)
    guard fd >= 0 else { throw fileError() }

    let temporary = String(cString: template)
    var replaced = false
    defer {
        if !replaced { _ = unlink(temporary) }
    }
    let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
    try handle.write(contentsOf: data)
    if let original, fchmod(fd, original.st_mode & 0o777) != 0 {
        throw fileError()
    }
    try handle.synchronize()
    try handle.close()

    let current = try fileInfo(path, followLinks: false)
    switch (original, current) {
    case (nil, nil):
        break
    case let (before?, after?) where sameRevision(before, after):
        break
    default:
        throw NSError(domain: NSPOSIXErrorDomain, code: Int(EBUSY))
    }
    guard rename(temporary, path) == 0 else { throw fileError() }
    replaced = true
}

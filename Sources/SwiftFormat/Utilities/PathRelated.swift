//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

/// Normalize path separators to forward slashes for consistent gitignore pattern matching
public func normalizePath(_ path: String) -> String {
#if SWIFT_FORMAT_ENABLE_NORMALIZE_PATH || os(Windows)
// On Windows, normalize backslashes to forward slashes for gitignore compatibility
return path.replacingOccurrences(of: #"\"#, with: "/")
#else
// On Unix systems, paths should already use forward slashes
return path
#endif
}

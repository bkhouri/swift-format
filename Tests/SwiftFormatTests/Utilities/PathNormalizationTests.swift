//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
@_spi(Internal) import SwiftFormat
import Testing

  // MARK: - Path Normalization Tests

  @Suite
  struct PathNormalizationTests {

    // Test data structure for path normalization
    struct PathTestCase {
      let testId: String
      let input: String
      let expected: String
    }

    #if os(Windows)
    static let windowsTestData = [
				PathTestCase(testId: "windows_basic_single", input: #"dir\file.swift"#, expected: "dir/file.swift"),
        PathTestCase(testId: "windows_basic_nested", input: #"src\main\App.swift"#, expected: "src/main/App.swift"),
        PathTestCase(testId: "windows_deep_nested", input: #"a\b\c\d.swift"#, expected: "a/b/c/d.swift"),
        PathTestCase(testId: "windows_fixture_keep", input: #"MyFix\myfix-keep.swift"#, expected: "MyFix/myfix-keep.swift"),
        PathTestCase(testId: "windows_fixture_negate", input: #"Fixture\MyFix\myfix-negate-in-subdir.swift"#, expected: "Fixture/MyFix/myfix-negate-in-subdir.swift"),
        PathTestCase(testId: "mixed_forward_back", input: #"dir/subdir\file.swift"#, expected: "dir/subdir/file.swift"),
        PathTestCase(testId: "mixed_complex", input: #"a\b/c\d.swift"#, expected: "a/b/c/d.swift"),
        PathTestCase(testId: "mixed_nested", input: #"src/main\App\File.swift"#, expected: "src/main/App/File.swift"),
        PathTestCase(testId: "mixed_root", input: #"\root/dir\file.swift"#, expected: "/root/dir/file.swift"),
        PathTestCase(testId: "edge_windows_single_backslash", input: #"\"#, expected: "/"),
        PathTestCase(testId: "edge_windows_double_backslash", input: #"\\"#, expected: "//"),
        PathTestCase(testId: "edge_windows_current_dir", input: #".\file.swift"#, expected: "./file.swift"),
        PathTestCase(testId: "edge_windows_parent_dir", input: #"..\parent\file.swift"#, expected: "../parent/file.swift"),
    ]
    #else
    static let windowsTestData: [PathTestCase] = []
    #endif

    @Test(arguments: [
        // Unix paths (should remain unchanged)
        PathTestCase(testId: "unix_basic", input: "dir/file.swift", expected: "dir/file.swift"),
        PathTestCase(testId: "unix_nested", input: "src/main/App.swift", expected: "src/main/App.swift"),
        PathTestCase(testId: "unix_deep", input: "a/b/c/d.swift", expected: "a/b/c/d.swift"),
        PathTestCase(testId: "unix_fixture", input: "MyFix/myfix-keep.swift", expected: "MyFix/myfix-keep.swift"),

        // Edge cases
        PathTestCase(testId: "edge_empty", input: "", expected: ""),
        PathTestCase(testId: "edge_no_separators", input: "file.swift", expected: "file.swift"),
        PathTestCase(testId: "edge_unix_single_slash", input: "/", expected: "/"),
        PathTestCase(testId: "edge_unix_double_slash", input: "//", expected: "//"),
        PathTestCase(testId: "edge_unix_current_dir", input: "./file.swift", expected: "./file.swift"),
        PathTestCase(testId: "edge_unix_parent_dir", input: "../parent/file.swift", expected: "../parent/file.swift"),
      ] + Self.windowsTestData,
    )
    func pathNormalization(testCase: PathTestCase) throws {
      // Test path normalization across all scenarios
      // #if os(Windows)
      let result = normalizePath(testCase.input)
      #expect(result == testCase.expected, "[\(testCase.testId)] Windows path '\(testCase.input)' should normalize to '\(testCase.expected)', got '\(result)'")
      // #else
      // // On Unix, simulate the normalization for validation
      // let result = testCase.input.replacingOccurrences(of: #"\"#, with: "/")
      // #expect(result == testCase.expected, "[\(testCase.testId)] Simulated path '\(testCase.input)' should normalize to '\(testCase.expected)', got '\(result)'")
      // #endif
    }
  }

  // MARK: - Windows Pattern Matching Tests

  @Suite
  struct WindowsPatternMatchingTests {

    // Test data structure for pattern matching
    struct PatternTestCase {
      let testId: String
      let pattern: String
      let windowsPath: String
      let shouldIgnore: Bool
    }

    #if os(Windows)
    static let windowsTestData = [
        PatternTestCase(testId: "negation_myfix_keep", pattern: "!MyFix/*-keep.swift", windowsPath: #"MyFix\myfix-keep.swift"#, shouldIgnore: false), // Should match (negated = don't ignore)
        PatternTestCase(testId: "directory_src", pattern: "src/", windowsPath: #"src\file.swift"#, shouldIgnore: true), // Directory pattern should match file inside
    ]
    #else
    static let windowsTestData: [PatternTestCase] = []
    #endif

    @Test(arguments: [
        // Test the exact patterns from the failing test case
        PatternTestCase(testId: "negation_negate_subdir", pattern: "!*-negate-in-subdir.swift", windowsPath: "myfix-negate-in-subdir.swift", shouldIgnore: false), // Should match
        PatternTestCase(testId: "negation_include", pattern: "!include*.swift", windowsPath: "include1.swift", shouldIgnore: false), // Should match
        PatternTestCase(testId: "directory_fixture", pattern: "Fixture/", windowsPath: #"Fixture\MyFix\file.swift"#, shouldIgnore: true), // Directory pattern should match nested file
      ] + Self.windowsTestData,
    )
    func windowsIgnorePatternMatching(testCase: PatternTestCase) throws {
      try withTempDirectory { tempDir in
        // Create ignore file with the test pattern
        let ignoreFile = tempDir.appendingPathComponent(".swift-format-ignore")
        try testCase.pattern.write(to: ignoreFile, atomically: true, encoding: .utf8)

        let manager = IgnoreManager()

        // Create a test file URL that simulates Windows path behavior
        // #if os(Windows)
        // On Windows, create the actual path structure
        let pathComponents = testCase.windowsPath.components(separatedBy: #"\"#)
        var fileURL = tempDir
        for component in pathComponents.dropLast() {
          fileURL = fileURL.appendingPathComponent(component)
          try? FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        }
        fileURL = fileURL.appendingPathComponent(pathComponents.last ?? "")
        // #else
        // // On Unix, simulate by creating a file with forward slashes
        // let normalizedPath = testCase.windowsPath.replacingOccurrences(of: #"\"#, with: "/")
        // let pathComponents = normalizedPath.components(separatedBy: "/")
        // var fileURL = tempDir
        // for component in pathComponents.dropLast() {
        //   fileURL = fileURL.appendingPathComponent(component)
        //   try? FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: true)
        // }
        // fileURL = fileURL.appendingPathComponent(pathComponents.last ?? "")
        // #endif

        let result = manager.shouldIgnore(file: fileURL, isDirectory: false)
        #expect(result == testCase.shouldIgnore, "[\(testCase.testId)] Pattern '\(testCase.pattern)' with path '\(testCase.windowsPath)' should ignore: \(testCase.shouldIgnore), got: \(result)")
      }
    }
  }

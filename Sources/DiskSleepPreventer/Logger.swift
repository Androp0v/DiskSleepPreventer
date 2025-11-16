//
//  Logger.swift
//  DiskSleepPreventer
//
//  Created by Raúl Montón Pinillos on 16/11/25.
//

import Darwin
import Foundation

struct Logger {
    static func info(_ message: String) {
        print(message)
    }

    static func warning(_ message: String) {
        if hasANSISupport {
            print("\u{001B}[33m\(message)\u{001B}[0m")
        } else {
            print(message)
        }
    }

    static func error(_ message: String) {
        if hasANSISupport {
            print("\u{001B}[31m\(message)\u{001B}[0m")
        } else {
            print(message)
        }
    }

    static var hasANSISupport: Bool {
        let rawEnvironment = getenv("TERM")
        guard let rawEnvironment else { return false }
        let environment = String(cString: rawEnvironment)
        switch environment {
        case "", "dumb", "cons25", "emacs":
            return false
        default:
            return true
        }
    }
}

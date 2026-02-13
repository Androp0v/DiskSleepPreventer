//
//  Logger.swift
//  DiskSleepPreventer
//
//  Created by Raúl Montón Pinillos on 16/11/25.
//

import ArgumentParser
import Darwin
import Foundation
import os

enum LoggerBackend {
    case os(Logger)
    case terminal
}

struct SharedLogger: Sendable, ExpressibleByArgument {

    let backend: LoggerBackend?

    // MARK: - Init

    init?(argument: String) {
        switch argument {
        case "os":
            self.backend = .os(Logger(
                subsystem: "DiskSleepPreventer",
                category: ""
            ))
        case "terminal":
            self.backend = .terminal
        default:
            return nil
        }
    }

    // MARK: - Logging

    func info(_ message: String) {
        switch backend {
        case .os(let logger):
            logger.info("\(message)")
        case .terminal:
            print(message)
        case .none:
            break
        }
    }

    func warning(_ message: String) {
        switch backend {
        case .os(let logger):
            logger.warning("\(message)")
        case .terminal:
            if Self.hasANSISupport {
                print("\u{001B}[33m\(message)\u{001B}[0m")
            } else {
                print(message)
            }
        case .none:
            break
        }
    }

    func error(_ message: String) {
        switch backend {
        case .os(let logger):
            logger.error("\(message)")
        case .terminal:
            if Self.hasANSISupport {
                print("\u{001B}[31m\(message)\u{001B}[0m")
            } else {
                print(message)
            }
        case .none:
            break
        }
    }

    // MARK: - Utilities

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

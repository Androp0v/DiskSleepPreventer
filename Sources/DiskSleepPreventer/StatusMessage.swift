//
//  File.swift
//  DiskSleepPreventer
//
//  Created by Raúl Montón Pinillos on 2/11/25.
//

import Foundation

enum StatusMessage {
    static func startupMessage(seconds: Double, disks: [String]) -> String {
        var result = "Will query the following disks every \(seconds) s to keep them awake:"
        for disk in disks {
            result.append("\n")
            result.append("- \(disk)")
        }
        return result
    }

    static func keepingAwake(disks: [Volume]) -> String {
        var result = "Keeping awake the mounted volumes:"
        for disk in disks {
            result.append("\n")
            result.append("- \(disk.name)")
        }
        return result
    }

    static func sleeping(for seconds: Double) -> String {
        "Sleeping for \(seconds) s..."
    }
}

//
//  Date+.swift
//  SnapClean
//
//  Created by Tung Nguyen on 28/02/2024.
//

import Foundation

extension Date {
    
    var displayText: String {
        if Calendar.current.isDateInToday(self) {
            return "Today"
        }
        if Calendar.current.isDateInYesterday(self) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd MMM yyyy"
        return formatter.string(from: self)
    }
    
}

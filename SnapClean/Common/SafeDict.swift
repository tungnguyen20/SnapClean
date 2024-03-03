//
//  SafeDict.swift
//  SnapClean
//
//  Created by Tung Nguyen on 03/03/2024.
//

import Foundation

class SafeDict {
    private var threadUnsafeDict = [String: Int32]()
    private let dispatchQueue = DispatchQueue(label: "thread.safe.dictionary", attributes: .concurrent)
    
    func getValue(key: String) -> Int32? {
        var result: Int32?
        dispatchQueue.sync {
            result = threadUnsafeDict[key]
        }
        return result
    }
    
    func setObject(key: String, value: Int32?) {
        dispatchQueue.async(flags: .barrier) {
            self.threadUnsafeDict[key] = value
        }
    }
}

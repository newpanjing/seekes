import Foundation
import AppKit

class JSONFormatter {
    static func format(_ value: Any, indentLevel: Int = 0) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let indent = String(repeating: "  ", count: indentLevel)
        
        if let dict = value as? [String: Any] {
            result.append(NSAttributedString(string: "{\n", attributes: [.foregroundColor: NSColor.labelColor]))
            let sortedKeys = dict.keys.sorted()
            for (index, key) in sortedKeys.enumerated() {
                result.append(NSAttributedString(string: "\(indent)  ", attributes: [.foregroundColor: NSColor.labelColor]))
                result.append(NSAttributedString(string: "\"\(key)\"", attributes: [.foregroundColor: NSColor.systemRed]))
                result.append(NSAttributedString(string: ": ", attributes: [.foregroundColor: NSColor.labelColor]))
                result.append(format(dict[key] as Any, indentLevel: indentLevel + 1))
                if index < sortedKeys.count - 1 {
                    result.append(NSAttributedString(string: ",", attributes: [.foregroundColor: NSColor.labelColor]))
                }
                result.append(NSAttributedString(string: "\n", attributes: [.foregroundColor: NSColor.labelColor]))
            }
            result.append(NSAttributedString(string: "\(indent)}", attributes: [.foregroundColor: NSColor.labelColor]))
        } else if let array = value as? [Any] {
            result.append(NSAttributedString(string: "[\n", attributes: [.foregroundColor: NSColor.labelColor]))
            for (index, item) in array.enumerated() {
                result.append(NSAttributedString(string: "\(indent)  ", attributes: [.foregroundColor: NSColor.labelColor]))
                result.append(format(item, indentLevel: indentLevel + 1))
                if index < array.count - 1 {
                    result.append(NSAttributedString(string: ",", attributes: [.foregroundColor: NSColor.labelColor]))
                }
                result.append(NSAttributedString(string: "\n", attributes: [.foregroundColor: NSColor.labelColor]))
            }
            result.append(NSAttributedString(string: "\(indent)]", attributes: [.foregroundColor: NSColor.labelColor]))
        } else if let string = value as? String {
            result.append(NSAttributedString(string: "\"\(escapeString(string))\"", attributes: [.foregroundColor: NSColor.systemRed]))
        } else if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                result.append(NSAttributedString(string: "\(number.boolValue)", attributes: [.foregroundColor: NSColor.systemPurple]))
            } else {
                result.append(NSAttributedString(string: "\(number)", attributes: [.foregroundColor: NSColor.systemGreen]))
            }
        } else if value is NSNull {
            result.append(NSAttributedString(string: "null", attributes: [.foregroundColor: NSColor.systemPurple]))
        } else if let bool = value as? Bool {
            result.append(NSAttributedString(string: "\(bool)", attributes: [.foregroundColor: NSColor.systemPurple]))
        } else if let intVal = value as? Int {
            result.append(NSAttributedString(string: "\(intVal)", attributes: [.foregroundColor: NSColor.systemGreen]))
        } else if let doubleVal = value as? Double {
            result.append(NSAttributedString(string: "\(doubleVal)", attributes: [.foregroundColor: NSColor.systemGreen]))
        } else {
            result.append(NSAttributedString(string: "\(value)", attributes: [.foregroundColor: NSColor.labelColor]))
        }
        
        return result
    }
    
    static func formatJSONString(_ jsonString: String) -> NSAttributedString {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
            return NSAttributedString(string: jsonString, attributes: [.foregroundColor: NSColor.labelColor])
        }
        return format(json)
    }
    
    private static func escapeString(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
    
    static func prettyPrint(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return prettyString
    }
}

extension Date {
    func formattedString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
}

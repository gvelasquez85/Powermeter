import Foundation
public struct PowerReading: Equatable {
    public let watts: Double
    public let label: String
    public static func parse(_ text: String) -> PowerReading? {
        let formats: [(String, String, Double)] = [
            (#"(?m)^CPU Power:\s*([0-9]+(?:\.[0-9]+)?)\s*mW\s*$"#, "CPU", 0.001),
            (#"(?m)^CPU Power:\s*([0-9]+(?:\.[0-9]+)?)\s*W\s*$"#, "CPU", 1.0),
            (#"(?m)^Intel energy model derived package power.*?:\s*([0-9]+(?:\.[0-9]+)?)\s*W\s*$"#, "Package", 1.0)
        ]
        for (pattern, label, scale) in formats {
            guard let regex = try? NSRegularExpression(pattern: pattern), let match = regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).last, let range = Range(match.range(at: 1), in: text), let value = Double(text[range]), value.isFinite, value >= 0 else { continue }
            return PowerReading(watts: value * scale, label: label)
        }
        return nil
    }
}

import Foundation
import PowerCore
let cases: [(String, Double?, String?)] = [
    ("CPU Power: 1250 mW", 1.25, "CPU"),
    ("CPU Power: 2.5 W", 2.5, "CPU"),
    ("Intel energy model derived package power (CPUs+GT+SA): 12.34W", 12.34, "Package"),
    ("GPU Power: 250 mW", nil, nil),
    ("CPU Power: -3 W", nil, nil),
    ("CPU Power: 1.2.3 W", nil, nil),
    ("CPU Power: 2 Wh", nil, nil),
    ("CPU Power: 100 mW\nCPU Power: 200 mW", 0.2, "CPU")
]
for (input, watts, label) in cases {
    let result = PowerReading.parse(input)
    precondition(result?.watts == watts && result?.label == label, "Unexpected parser result: \(input)")
}
print("PASS: \(cases.count) parser cases")

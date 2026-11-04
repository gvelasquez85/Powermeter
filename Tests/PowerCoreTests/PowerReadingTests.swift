import XCTest
@testable import PowerCore
final class PowerReadingTests: XCTestCase {
    func testAppleSiliconMilliwatts() { XCTAssertEqual(PowerReading.parse("CPU Power: 1250 mW")?.watts, 1.25) }
    func testIntelPackage() { let reading = PowerReading.parse("Intel energy model derived package power (CPUs+GT+SA): 12.34W"); XCTAssertEqual(reading?.watts, 12.34); XCTAssertEqual(reading?.label, "Package") }
    func testInvalidOutput() { for input in ["", "CPU Power: -1 W", "CPU Power: nan W", "GPU Power: 100 mW"] { XCTAssertNil(PowerReading.parse(input)) } }
    func testLastSample() { XCTAssertEqual(PowerReading.parse("CPU Power: 100 mW\nCPU Power: 200 mW")?.watts, 0.2) }
}

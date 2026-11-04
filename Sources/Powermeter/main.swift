import AppKit
import SwiftUI
import Charts
import ServiceManagement
import PowerCore

struct Sample: Identifiable { let id = UUID(); let date = Date(); let watts: Double }
@MainActor final class Monitor: ObservableObject {
    @Published var reading: PowerReading?
    @Published var samples: [Sample] = []
    @Published var status = "Iniciando monitor…"
    @Published var busy = false
    @Published var failed = false
    @Published var interval = UserDefaults.standard.integer(forKey: "interval") == 0 ? 2 : UserDefaults.standard.integer(forKey: "interval")
    @Published var login = SMAppService.mainApp.status == .enabled
    private let collector = Collector()
    private var collectorURL: URL?
    private var pollTask: Task<Void, Never>?
    private var lastSize: UInt64 = 0
    private var pending = Data()
    private var startedAt = Date()
    private var lastUpdate = Date()
    private var receivedReading = false
    private var generation = UUID()
    var compact: String { reading.map { String(format: "%.1fW", $0.watts) } ?? (failed ? "!W" : "…W") }
    var thermal: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Normal"
        case .fair: return "Moderado"
        case .serious: return "Elevado"
        case .critical: return "Crítico"
        @unknown default: return "Desconocido"
        }
    }
    init() {
        if ![1,2,5].contains(interval) { interval = 2 }
        Task { await start() }
    }
    func start() async {
        guard !busy else { return }
        busy = true; failed = false; reading = nil; status = "Autoriza macOS para leer el consumo."
        let token = UUID(); generation = token
        do {
            let url = try await collector.start(interval: interval)
            guard generation == token else { collector.stop(); return }
            collectorURL = url; lastSize = 0; pending.removeAll(); receivedReading = false
            samples.removeAll(); startedAt = Date(); lastUpdate = Date()
            status = "Esperando la primera muestra…"
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard !Task.isCancelled, let self else { return }
                    self.readSample()
                    if !self.busy { return }
                    if Date().timeIntervalSince(self.startedAt) >= 43190 {
                        self.stop(); await self.start(); return
                    }
                }
            }
        } catch {
            guard generation == token else { return }
            stop(); failed = true; status = error.localizedDescription
        }
    }
    private func fail(_ message: String) { stop(); failed = true; status = message }
    private func readSample() {
        if let failure = collector.failure { fail(failure); return }
        guard let collectorURL else { return }
        guard FileManager.default.fileExists(atPath: collectorURL.path) else {
            fail("El recolector se cerró. Reintenta para volver a autorizarlo."); return
        }
        do {
            let handle = try FileHandle(forReadingFrom: collectorURL)
            defer { try? handle.close() }
            try handle.seek(toOffset: lastSize)
            let data = try handle.read(upToCount: 262144) ?? Data()
            lastSize += UInt64(data.count); pending.append(data)
            if pending.count > 524288 { fail("El recolector devolvió una respuesta demasiado grande."); return }
            if let newline = pending.lastIndex(of: 10) {
                let complete = Data(pending[...newline]); pending.removeSubrange(...newline)
                if let text = String(data: complete, encoding: .utf8), text.contains("POWERMETER_EXIT=") {
                    fail("El recolector terminó: " + text.suffix(600)); return
                }
                if let text = String(data: complete, encoding: .utf8), let value = PowerReading.parse(text) {
                    lastUpdate = Date(); reading = value; receivedReading = true
                    samples.append(Sample(watts: value.watts)); samples = Array(samples.suffix(60))
                    status = "Actualizado \(lastUpdate.formatted(date: .omitted, time: .standard))"
                }
            }
        } catch { fail("No se pudo leer el consumo: \(error.localizedDescription)"); return }
        let age = Date().timeIntervalSince(lastUpdate)
        if age > Double(max(interval * 3, 8)) { reading = nil; status = "Sin datos recientes…" }
        if age > Double(max(interval * 6, 20)) {
            fail(receivedReading ? "Se interrumpió la medición. Reintenta para reconectar." : "macOS no entregó una lectura compatible. Reintenta o consulta el diagnóstico.")
        }
    }
    func stop() {
        generation = UUID(); pollTask?.cancel(); pollTask = nil; collector.stop()
        collectorURL = nil; busy = false; reading = nil
    }
    func retry() { stop(); Task { await start() } }
    func changeInterval(_ value: Int) {
        interval = value; UserDefaults.standard.set(value, forKey: "interval")
        retry()
    }
    func setLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            login = SMAppService.mainApp.status == .enabled
        } catch { status = "Inicio automático: \(error.localizedDescription)" }
    }
}

struct Panel: View {
    @ObservedObject var model: Monitor
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Powermeter").font(.headline)
                Spacer()
                Circle().fill(model.reading != nil ? Color.green : model.failed ? Color.orange : Color.secondary).frame(width: 6, height: 6)
                Text(model.reading != nil ? "En directo" : model.failed ? "Sin conexión" : "Conectando").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(model.reading.map { String(format: "%.1f", $0.watts) } ?? "—").font(.system(size: 42, weight: .medium, design: .rounded)).monospacedDigit()
                Text("W").font(.title3).foregroundStyle(.secondary)
                Spacer()
                Text(model.reading?.label == "Package" ? "Paquete del chip" : "Procesador").font(.caption).foregroundStyle(.secondary)
            }
            if model.samples.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: model.failed ? "exclamationmark.triangle" : "waveform.path").font(.title2).foregroundStyle(.secondary)
                    Text(model.failed ? "No se están recibiendo mediciones" : "El historial aparecerá al recibir datos").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).frame(height: 84)
            } else {
                Chart(model.samples) { sample in
                    AreaMark(x: .value("Hora", sample.date), y: .value("Vatios", sample.watts)).foregroundStyle(.blue.opacity(0.10))
                    LineMark(x: .value("Hora", sample.date), y: .value("Vatios", sample.watts)).foregroundStyle(.blue)
                }.chartXAxis(.hidden).frame(height: 84).accessibilityLabel("Historial de potencia en vatios")
            }
            HStack { Label("Estado térmico", systemImage: "thermometer.medium"); Spacer(); Text(model.thermal).foregroundStyle(.secondary) }.font(.caption)
            Text(model.status).font(.caption).foregroundStyle(model.failed ? .primary : .secondary).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            if model.failed { Button("Reintentar conexión", action: model.retry).buttonStyle(.borderedProminent).frame(maxWidth: .infinity) }
            Divider()
            HStack {
                Text("Actualizar cada").font(.caption)
                Picker("Intervalo de actualización", selection: Binding(get: { model.interval }, set: model.changeInterval)) {
                    Text("1 s").tag(1); Text("2 s").tag(2); Text("5 s").tag(5)
                }.labelsHidden().pickerStyle(.segmented).frame(width: 145).disabled(model.busy && model.reading == nil)
            }
            Toggle("Abrir al iniciar sesión", isOn: Binding(get: { model.login }, set: model.setLogin)).font(.caption)
            HStack {
                Text("Potencia estimada").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Button("Salir") { model.stop(); NSApplication.shared.terminate(nil) }.buttonStyle(.plain).font(.caption)
            }
        }.padding(18).frame(width: 300)
    }
}
@main struct PowermeterApp: App {
    @StateObject private var model = Monitor()
    var body: some Scene {
        MenuBarExtra {
            Panel(model: model)
        } label: {
            Text(model.compact).font(.system(size: 11, weight: .medium, design: .monospaced))
                .accessibilityLabel(model.reading.map { "Consumo: \($0.watts) vatios" } ?? model.status)
        }.menuBarExtraStyle(.window)
    }
}

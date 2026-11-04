import AppKit
import Foundation

/// Keeps the authorized foreground shell alive for the entire sampling session.
/// Only system binaries and inline, fixed shell source execute with elevation.
@MainActor final class Collector {
    private(set) var failure: String?
    private var controlURL: URL?
    private var sessionID = UUID()

    enum CollectorError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
    }

    private nonisolated static let executionLock = NSLock()

    private nonisolated static func execute(_ command: String) -> (String?, String?) {
        executionLock.lock()
        defer { executionLock.unlock() }
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "with timeout of 86400 seconds\ndo shell script \"\(escaped)\" with administrator privileges\nend timeout"
        var error: NSDictionary?
        let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue
        return (output, error?[NSAppleScript.errorMessage] as? String)
    }

    func start(interval: Int) async throws -> URL {
        stop()
        guard [1, 2, 5].contains(interval) else { throw CollectorError.message("Intervalo de medición inválido.") }
        let id = UUID(); sessionID = id; failure = nil
        let control = URL(fileURLWithPath: "/private/tmp/powermeter-control." + UUID().uuidString)
        guard FileManager.default.createFile(atPath: control.path, contents: Data(), attributes: [.posixPermissions: 0o600]) else {
            throw CollectorError.message("No se pudo preparar la sesión de medición.")
        }
        controlURL = control
        let gid = getgid()
        let preparation = "p=$(/usr/bin/mktemp /private/tmp/powermeter.XXXXXXXX) || exit 1; /usr/bin/chgrp \(gid) \"$p\" && /bin/chmod 640 \"$p\" || { /bin/rm -f \"$p\"; exit 1; }; /bin/echo \"$p\""
        let created = await Task.detached { Self.execute(preparation) }.value
        guard id == sessionID else { throw CancellationError() }
        guard let path = created.0?.trimmingCharacters(in: .whitespacesAndNewlines),
              path.range(of: #"^/private/tmp/powermeter\.[A-Za-z0-9]{8}$"#, options: .regularExpression) != nil else {
            stop(); throw CollectorError.message(created.1 ?? "No se pudo autorizar la medición.")
        }
        let output = URL(fileURLWithPath: path)
        let pid = ProcessInfo.processInfo.processIdentifier
        // Paths contain only fixed ASCII prefixes and UUID/mktemp suffixes.
        // File is root-owned in sticky /private/tmp; the app cannot replace it.
        let command = """
        p='\(path)'; app=\(pid); control='\(control.path)'; child=''; watcher='';
        cleanup() { [ -z "$child" ] || /bin/kill "$child" 2>/dev/null; [ -z "$watcher" ] || /bin/kill "$watcher" 2>/dev/null; /bin/sleep 5; /bin/rm -f "$p"; };
        trap cleanup EXIT; trap 'exit 0' HUP INT TERM;
        [ -f "$control" ] && /bin/kill -0 "$app" 2>/dev/null || exit 1;
        [ "$(/usr/bin/stat -f %u "$p")" = 0 ] && [ ! -L "$p" ] || exit 1;
        /bin/echo POWERMETER_READY >> "$p";
        /usr/bin/powermetrics --samplers cpu_power -n \(43200 / interval) -i \(interval * 1000) -b 1 >> "$p" 2>&1 & child=$!;
        ( ticks=0; while /bin/kill -0 "$child" 2>/dev/null; do ticks=$((ticks+1)); if [ ! -f "$control" ] || ! /bin/kill -0 "$app" 2>/dev/null || [ "$ticks" -gt 21600 ]; then /bin/kill "$child" 2>/dev/null; exit; fi; /bin/sleep 2; done ) & watcher=$!;
        wait "$child"; result=$?; child=''; /bin/echo "POWERMETER_EXIT=$result" >> "$p"; exit "$result"
        """
        Task { [weak self] in
            let result = await Task.detached { Self.execute(command) }.value
            guard let self, self.sessionID == id else { return }
            self.failure = result.1 ?? "La sesión de medición ha finalizado."
        }
        // Authorization may take time; wait without blocking the main actor.
        for _ in 0..<600 {
            guard id == sessionID else { throw CancellationError() }
            if let failure { stop(); throw CollectorError.message(failure) }
            if let handle = try? FileHandle(forReadingFrom: output) {
                let data = try? handle.read(upToCount: 64)
                try? handle.close()
                if let data, String(decoding: data, as: UTF8.self).contains("POWERMETER_READY") { return output }
            }
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        stop(); throw CollectorError.message("El recolector no confirmó el inicio. Reintenta y acepta el diálogo de macOS.")
    }

    func stop() {
        sessionID = UUID()
        if let controlURL { try? FileManager.default.removeItem(at: controlURL) }
        controlURL = nil
    }
}

import Foundation

/// Manages a PTY (pseudo-terminal) process for running Claude Code
class TerminalProcess {
    private var process: Process?
    private var masterFd: Int32 = -1
    private var slaveFd: Int32 = -1

    let directory: String
    let environment: [String: String]

    var onOutput: ((String) -> Void)?
    var onStatusChange: ((Bool) -> Void)?

    private var outputBuffer = Data()
    private var readSource: DispatchSourceRead?

    init(directory: String, environment: [String: String] = [:]) {
        self.directory = directory
        self.environment = environment
    }

    deinit {
        terminate()
    }

    func start(command: String = "claude") {
        // Create pseudo-terminal
        var masterFd: Int32 = 0
        var slaveFd: Int32 = 0

        // Open PTY master/slave pair
        if openpty(&masterFd, &slaveFd, nil, nil, nil) != 0 {
            print("Failed to open PTY")
            return
        }

        self.masterFd = masterFd
        self.slaveFd = slaveFd

        // Create the process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: directory)

        // Set up environment
        var env = ProcessInfo.processInfo.environment
        for (key, value) in environment {
            env[key] = value
        }
        // Ensure proper terminal settings
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        process.environment = env

        // Use the slave PTY for stdin/stdout/stderr
        let slaveHandle = FileHandle(fileDescriptor: slaveFd, closeOnDealloc: false)
        process.standardInput = slaveHandle
        process.standardOutput = slaveHandle
        process.standardError = slaveHandle

        // Set up output reading from master
        setupOutputReading()

        // Handle process termination
        process.terminationHandler = { [weak self] _ in
            self?.onStatusChange?(false)
        }

        self.process = process

        do {
            try process.run()
            onStatusChange?(true)
        } catch {
            print("Failed to start process: \(error)")
            onStatusChange?(false)
        }
    }

    func sendInput(_ text: String) {
        guard masterFd >= 0 else { return }

        if let data = text.data(using: .utf8) {
            data.withUnsafeBytes { ptr in
                if let baseAddress = ptr.baseAddress {
                    _ = write(masterFd, baseAddress, ptr.count)
                }
            }
        }
    }

    func terminate() {
        readSource?.cancel()
        readSource = nil

        process?.terminate()
        process = nil

        if masterFd >= 0 {
            close(masterFd)
            masterFd = -1
        }
        if slaveFd >= 0 {
            close(slaveFd)
            slaveFd = -1
        }
    }

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Private

    private func setupOutputReading() {
        guard masterFd >= 0 else { return }

        // Set non-blocking
        let flags = fcntl(masterFd, F_GETFL)
        fcntl(masterFd, F_SETFL, flags | O_NONBLOCK)

        // Create dispatch source for reading
        let source = DispatchSource.makeReadSource(fileDescriptor: masterFd, queue: .global())

        source.setEventHandler { [weak self] in
            self?.readAvailableData()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.masterFd, fd >= 0 {
                close(fd)
            }
        }

        source.resume()
        self.readSource = source
    }

    private func readAvailableData() {
        var buffer = [UInt8](repeating: 0, count: 4096)

        let bytesRead = read(masterFd, &buffer, buffer.count)
        if bytesRead > 0 {
            let data = Data(bytes: buffer, count: bytesRead)
            if let string = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.onOutput?(string)
                }
            }
        }
    }
}

// C function imports for PTY
import Darwin

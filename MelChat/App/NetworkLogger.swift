import Foundation
import UIKit
import Combine

// MARK: - Network Logger
@MainActor
class NetworkLogger: ObservableObject {
    static let shared = NetworkLogger()
    
    @Published var logs: [NetworkLog] = []
    @Published var isEnabled = true
    
    private let maxLogs = 100
    
    private init() {}
    
    func log(_ message: String) {
        guard isEnabled else { return }
        let log = NetworkLog(
            timestamp: Date(),
            type: .info,
            message: message
        )
        addLog(log)
        print(message)
    }
    
    func logRequest<B: Encodable>(_ request: URLRequest, body: B? = nil) {
        guard isEnabled else { return }
        
        var message = "📤 REQUEST\n"
        message += "URL: \(request.url?.absoluteString ?? "nil")\n"
        message += "Method: \(request.httpMethod ?? "nil")\n"
        
        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            message += "Headers:\n"
            headers.forEach { key, value in
                message += "  \(key): \(value)\n"
            }
        }
        
        if let body = body {
            if let jsonData = try? JSONEncoder().encode(body),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                message += "Body: \(jsonString)"
            }
        }
        
        let log = NetworkLog(
            timestamp: Date(),
            type: .request,
            message: message,
            url: request.url?.absoluteString
        )
        addLog(log)
        print(message)
    }
    
    func logResponse(_ response: HTTPURLResponse, data: Data) {
        guard isEnabled else { return }
        
        var message = "📥 RESPONSE\n"
        message += "URL: \(response.url?.absoluteString ?? "nil")\n"
        message += "Status: \(response.statusCode)\n"
        
        if let jsonString = String(data: data, encoding: .utf8) {
            // Pretty print JSON
            if let jsonData = jsonString.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                message += "Body:\n\(prettyString)"
            } else {
                message += "Body: \(jsonString)"
            }
        }
        
        let log = NetworkLog(
            timestamp: Date(),
            type: .response,
            message: message,
            statusCode: response.statusCode,
            url: response.url?.absoluteString
        )
        addLog(log)
        print(message)
    }
    
    private func addLog(_ log: NetworkLog) {
        logs.append(log)
        if logs.count > maxLogs {
            logs.removeFirst()
        }
    }
    
    func clear() {
        logs.removeAll()
    }
}

// MARK: - Network Log Model
struct NetworkLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: LogType
    let message: String
    var statusCode: Int?
    var url: String?
    
    enum LogType {
        case info, request, response, error
        
        var icon: String {
            switch self {
            case .info: return "ℹ️"
            case .request: return "📤"
            case .response: return "📥"
            case .error: return "❌"
            }
        }
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .request: return "orange"
            case .response: return "green"
            case .error: return "red"
            }
        }
    }
}

// MARK: - Network Logger View
import SwiftUI

struct NetworkLoggerView: View {
    @ObservedObject var logger = NetworkLogger.shared
    @State private var searchText = ""
    @State private var selectedLog: NetworkLog?
    
    var filteredLogs: [NetworkLog] {
        if searchText.isEmpty {
            return logger.logs.reversed()
        }
        return logger.logs.reversed().filter { log in
            log.message.localizedCaseInsensitiveContains(searchText) ||
            log.url?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats
                HStack(spacing: 20) {
                    statView(
                        title: "Total",
                        value: "\(logger.logs.count)",
                        color: .blue
                    )
                    statView(
                        title: "Requests",
                        value: "\(logger.logs.filter { $0.type == .request }.count)",
                        color: .orange
                    )
                    statView(
                        title: "Responses",
                        value: "\(logger.logs.filter { $0.type == .response }.count)",
                        color: .green
                    )
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // Logs list
                List {
                    ForEach(filteredLogs) { log in
                        Button {
                            selectedLog = log
                        } label: {
                            LogRow(log: log)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .searchable(text: $searchText, prompt: "Search logs...")
            }
            .navigationTitle("Network Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        logger.clear()
                    }
                }
            }
            .sheet(item: $selectedLog) { log in
                NavigationStack {
                    LogDetailView(log: log)
                }
            }
        }
    }
    
    private func statView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LogRow: View {
    let log: NetworkLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.type.icon)
                Text(log.timestamp, style: .time)
                    .font(.caption.monospacedDigit())
                Spacer()
                if let statusCode = log.statusCode {
                    statusBadge(statusCode)
                }
            }
            
            if let url = log.url {
                Text(url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Text(log.message)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
    
    private func statusBadge(_ code: Int) -> some View {
        Text(String(code))
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusColor(code).opacity(0.2))
            .foregroundStyle(statusColor(code))
            .clipShape(Capsule())
    }
    
    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        default: return .red
        }
    }
}

struct LogDetailView: View {
    let log: NetworkLog
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(log.type.icon)
                            .font(.title)
                        Text(log.timestamp, style: .time)
                            .font(.title3.bold())
                        Spacer()
                        if let statusCode = log.statusCode {
                            Text(String(statusCode))
                                .font(.title3.bold())
                                .foregroundStyle(statusColor(statusCode))
                        }
                    }
                    
                    if let url = log.url {
                        Text(url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Message
                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.headline)
                    
                    Text(log.message)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
        }
        .navigationTitle("Log Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: return .green
        case 300..<400: return .blue
        case 400..<500: return .orange
        default: return .red
        }
    }
}

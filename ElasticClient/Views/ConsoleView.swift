import SwiftUI
import AppKit

struct ConsoleView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            if !appState.isConnected {
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("请先连接到Elasticsearch")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Spacer()
                    Button {
                        Task { await documentVM.executeConsoleQuery() }
                    } label: {
                        Label("执行", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(documentVM.consoleIsLoading)
                    .help("执行请求")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
                HSplitView {
                    // Query Editor
                    VStack(spacing: 0) {
                        HStack {
                            Text("请求")
                                .font(.headline)
                                .padding(12)
                            Spacer()
                            Button(action: {
                                documentVM.consoleText = "GET /_cat/indices?v"
                            }) {
                                Label("重置", systemImage: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                            .help("重置请求")
                        }
                        Divider()
                        
                        ConsoleEditor(text: $documentVM.consoleText)
                            .frame(minWidth: 300)
                    }
                    
                    // Response
                    VStack(spacing: 0) {
                        HStack {
                            Text("响应")
                                .font(.headline)
                                .padding(12)
                            Spacer()
                            if documentVM.consoleIsLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .padding(12)
                            }
                        }
                        Divider()
                        
                        ResponseViewer(attributedText: documentVM.consoleResult ?? NSAttributedString(string: AppLanguage.localizedString("执行查询后将在此显示结果..."), attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

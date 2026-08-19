import SwiftUI
import AppKit

struct ConsoleView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("控制台")
                        .font(.system(size: 24, weight: .bold))
                    Text("执行 Elasticsearch 查询")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: {
                    Task {
                        await documentVM.executeConsoleQuery()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                        Text("执行")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(documentVM.consoleIsLoading || !appState.isConnected)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
            
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
                                Image(systemName: "trash")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
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
                        
                        ResponseViewer(attributedText: documentVM.consoleResult ?? NSAttributedString(string: "执行查询后将在此显示结果...", attributes: [.foregroundColor: NSColor.secondaryLabelColor]))
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

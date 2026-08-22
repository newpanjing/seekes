import SwiftUI

struct DocumentOperationPanelView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    documentVM.showOperationPanel = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    operationsSection
                    
                    if documentVM.isLoading {
                        ProgressView("处理中...")
                    }
                }
                .padding(.horizontal, 16)
            }
            
            Spacer()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var operationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文档操作")
                .font(.system(size: 15, weight: .semibold))
            
            if let doc = documentVM.selectedDocument {
                VStack(alignment: .leading, spacing: 6) {
                    Text("文档 ID")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text(doc.id)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        
                        Spacer()
                        
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(doc.id, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.textBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("所属索引")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    Text(doc.index)
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("操作")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    OperationButton(
                        icon: "doc.text",
                        title: "查看文档",
                        isSelected: documentVM.documentOperation == .view,
                        hasIndicator: false
                    ) {
                        documentVM.setOperation(.view)
                    }
                    
                    OperationButton(
                        icon: "pencil",
                        title: "更新文档",
                        isSelected: documentVM.documentOperation == .update,
                        hasIndicator: true
                    ) {
                        documentVM.startEditing()
                    }
                    
                    OperationButton(
                        icon: "trash",
                        title: "删除文档",
                        isSelected: documentVM.documentOperation == .delete,
                        hasIndicator: false,
                        isDestructive: true
                    ) {
                        NSAlert.showConfirmation(
                            title: AppLanguage.localizedString("删除文档"),
                            message: AppLanguage.localizedString("确定要删除该文档吗？此操作不可撤销。")
                        ) { confirmed in
                            if confirmed {
                                Task {
                                    await documentVM.deleteDocument()
                                }
                            }
                        }
                    }
                }
                
                if let detail = documentVM.selectedDocumentDetail {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("元数据")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            if let version = detail.version {
                                HStack {
                                    Text("版本")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(version)")
                                        .font(.system(size: 11, design: .monospaced))
                                }
                            }
                            
                            if let seqNo = detail.seqNo {
                                HStack {
                                    Text("序列号")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(seqNo)")
                                        .font(.system(size: 11, design: .monospaced))
                                }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
            } else {
                Text("选择一个文档查看详情")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
            }
        }
    }
}

struct OperationButton: View {
    let icon: String
    let title: LocalizedStringKey
    let isSelected: Bool
    let hasIndicator: Bool
    var isDestructive: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13))
                
                Spacer()
                
                if hasIndicator {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(isDestructive ? .red : (isSelected ? .blue : .primary))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                isSelected ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

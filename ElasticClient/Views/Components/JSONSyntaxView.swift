import SwiftUI
import AppKit

// MARK: - 应用图标
/// 统一展示系统加载的应用图标，避免界面品牌标识与应用图标不一致。
struct AppLogoView: View {
    var size: CGFloat = 32
    
    var body: some View {
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityLabel("SeekES")
    }
}

// MARK: - Response Viewer (Read-only JSON)
struct ResponseViewer: NSViewRepresentable {
    let attributedText: NSAttributedString
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.allowsUndo = false
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            textView.textStorage?.setAttributedString(attributedText)
        }
    }
}

/// 以原生大纲展示 JSON，支持逐层折叠和展开对象、数组。
struct CollapsibleJSONView: NSViewRepresentable {
    let jsonText: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let outlineView = NSOutlineView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("json"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.headerView = nil
        outlineView.rowHeight = -1
        outlineView.usesAutomaticRowHeights = true
        outlineView.indentationPerLevel = 16
        outlineView.selectionHighlightStyle = .none
        outlineView.delegate = context.coordinator
        outlineView.dataSource = context.coordinator
        context.coordinator.update(jsonText: jsonText, outlineView: outlineView)
        scrollView.documentView = outlineView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let outlineView = nsView.documentView as? NSOutlineView else { return }
        context.coordinator.update(jsonText: jsonText, outlineView: outlineView)
    }

    final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
        private var source = ""
        private var nodes: [Node] = []

        /// 输入变化后重建树，保持视图只处理 JSON 展示职责。
        func update(jsonText: String, outlineView: NSOutlineView) {
            guard source != jsonText else { return }
            source = jsonText
            nodes = JSONTreeParser.nodes(from: jsonText)
            outlineView.reloadData()
            outlineView.expandItem(nil, expandChildren: true)
        }

        func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
            (item as? Node)?.children.count ?? nodes.count
        }

        func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
            ((item as? Node)?.children ?? nodes)[index]
        }

        func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
            (item as? Node)?.children.isEmpty == false
        }

        func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
            guard let node = item as? Node else { return nil }
            let identifier = NSUserInterfaceItemIdentifier("json-cell")
            let cell = outlineView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView ?? NSTableCellView()
            let textField = cell.textField ?? NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            textField.isSelectable = true
            textField.lineBreakMode = .byWordWrapping
            textField.maximumNumberOfLines = 0
            textField.attributedStringValue = node.attributedTitle
            if cell.textField == nil {
                textField.translatesAutoresizingMaskIntoConstraints = false
                cell.addSubview(textField)
                NSLayoutConstraint.activate([
                    textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                    textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                    textField.topAnchor.constraint(equalTo: cell.topAnchor, constant: 2),
                    textField.bottomAnchor.constraint(equalTo: cell.bottomAnchor, constant: -2)
                ])
                cell.textField = textField
                cell.identifier = identifier
            }
            return cell
        }

        /// 为当前 JSON 节点提供完整的复制操作，保留自由文本选择能力。
        func outlineView(_ outlineView: NSOutlineView, menuForEvent event: NSEvent) -> NSMenu? {
            let location = outlineView.convert(event.locationInWindow, from: nil)
            let row = outlineView.row(at: location)
            guard row >= 0, let node = outlineView.item(atRow: row) as? Node else { return nil }
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)

            let menu = NSMenu()
            menu.addItem(copyItem(title: "复制", value: node.displayText))
            if let key = node.key {
                menu.addItem(copyItem(title: "复制键", value: key))
            }
            menu.addItem(copyItem(title: "复制值", value: node.valueText))
            menu.addItem(copyItem(title: "复制全部", value: node.fullText))
            return menu
        }

        private func copyItem(title: String, value: String) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(copyMenuValue(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = value
            return item
        }

        @objc private func copyMenuValue(_ sender: NSMenuItem) {
            guard let value = sender.representedObject as? String else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
        }
    }

    private final class Node: NSObject {
        let key: String?
        let value: Any
        let children: [Node]
        let attributedTitle: NSAttributedString

        init(key: String?, value: Any) {
            self.key = key
            self.value = value
            children = JSONTreeParser.children(for: value)
            attributedTitle = JSONTreeParser.title(key: key, value: value, hasChildren: !children.isEmpty)
        }

        var displayText: String { attributedTitle.string }
        var valueText: String { JSONTreeParser.valueText(value) }
        var fullText: String { key.map { "\($0): \(valueText)" } ?? valueText }
    }

    private enum JSONTreeParser {
        static func nodes(from text: String) -> [Node] {
            guard let data = text.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) else {
                return [Node(key: nil, value: text)]
            }
            return children(for: object)
        }

        static func children(for value: Any) -> [Node] {
            if let object = value as? [String: Any] {
                return object.keys.sorted().compactMap { key in
                    object[key].map { Node(key: key, value: $0) }
                }
            }
            if let values = value as? [Any] {
                return values.enumerated().map { Node(key: "[\($0.offset)]", value: $0.element) }
            }
            return []
        }

        static func title(key: String?, value: Any, hasChildren: Bool) -> NSAttributedString {
            let result = NSMutableAttributedString()
            if let key {
                result.append(NSAttributedString(string: "\"\(key)\": ", attributes: [.foregroundColor: NSColor.systemRed]))
            }
            let text: String
            let color: NSColor
            if hasChildren, value is [String: Any] {
                text = "{ … }"
                color = .secondaryLabelColor
            } else if hasChildren, value is [Any] {
                text = "[ … ]"
                color = .secondaryLabelColor
            } else if value is NSNull {
                text = "null"
                color = .systemPurple
            } else if let bool = value as? Bool {
                text = bool ? "true" : "false"
                color = .systemPurple
            } else if let string = value as? String {
                text = "\"\(string)\""
                color = .systemGreen
            } else {
                text = "\(value)"
                color = .systemBlue
            }
            result.append(NSAttributedString(string: text, attributes: [.foregroundColor: color]))
            return result
        }

        static func valueText(_ value: Any) -> String {
            if JSONSerialization.isValidJSONObject(value),
               let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]),
               let text = String(data: data, encoding: .utf8) {
                return text
            }
            if value is NSNull { return "null" }
            if let value = value as? String { return value }
            return "\(value)"
        }
    }
}

// MARK: - Console Editor (Editable JSON)
struct ConsoleEditor: NSViewRepresentable {
    @Binding var text: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        
        scrollView.documentView = textView
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
        }
    }
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ConsoleEditor
        
        init(_ parent: ConsoleEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// 可编辑 JSON 文本框；输入过程中保持 JSON 语法颜色，格式化由上层按钮触发。
struct JSONEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.drawsBackground = false
        let textView = NSTextView(frame: .zero)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 16, height: 12)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.string = text
        scrollView.documentView = textView
        scrollView.verticalRulerView = JSONLineNumberRulerView(scrollView: scrollView, textView: textView)
        applySyntax(to: textView)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        context.coordinator.replaceTextIfNeeded(text, in: textView)
    }

    private func applySyntax(to textView: NSTextView) {
        let source = textView.string
        let selections = textView.selectedRanges
        let highlighted = JSONFormatter.formatJSONString(source)
        textView.textStorage?.setAttributedString(highlighted)
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.selectedRanges = selections
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: JSONEditor
        private var isApplyingSyntax = false
        private var editorText = ""

        init(_ parent: JSONEditor) { self.parent = parent }

        /// 仅在 SwiftUI 外部状态变化时覆盖编辑器内容，避免每次输入后重置光标。
        func replaceTextIfNeeded(_ text: String, in textView: NSTextView) {
            guard text != editorText else { return }
            isApplyingSyntax = true
            textView.string = text
            editorText = text
            parent.applySyntax(to: textView)
            isApplyingSyntax = false
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingSyntax, let textView = notification.object as? NSTextView else { return }
            editorText = textView.string
            parent.text = textView.string
            isApplyingSyntax = true
            parent.applySyntax(to: textView)
            isApplyingSyntax = false
        }
    }
}

/// 与 JSON 编辑器滚动位置同步的最小行号标尺。
private final class JSONLineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let textAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor.secondaryLabelColor
    ]

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 36
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        let visibleRect = scrollView?.contentView.bounds ?? .zero
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let content = textView.string as NSString
        var characterIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)
        var lineNumber = content.substring(to: characterIndex).filter { $0 == "\n" }.count + 1

        while characterIndex < content.length {
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            if lineRect.minY > visibleRect.maxY { break }
            let text = "\(lineNumber)" as NSString
            let textSize = text.size(withAttributes: textAttributes)
            text.draw(
                at: NSPoint(x: ruleThickness - textSize.width - 6, y: lineRect.minY + textView.textContainerInset.height),
                withAttributes: textAttributes
            )
            let range = content.lineRange(for: NSRange(location: characterIndex, length: 0))
            characterIndex = NSMaxRange(range)
            lineNumber += 1
        }
    }
}

// Keep old name for compatibility
typealias JSONSyntaxView = ResponseViewer

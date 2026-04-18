import AppKit
import SwiftUI

struct SettingsPopoverCategoryPickerField: View {
    @Binding var isPresented: Bool
    let availableTags: [String]
    let selectedTagName: String?
    let selectedTagTitle: String
    let onSelectTag: (String?) -> Void
    let onCreateTag: () -> Void
    let onRenameTag: (String) -> Void
    let onDeleteTag: (String) -> Void

    var body: some View {
        Button(action: { isPresented.toggle() }) {
            HStack(spacing: FocusPanelSpacing.sm) {
                Text(selectedTagTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .font(FocusPanelTypography.bodyLabel)
            .foregroundColor(.primary)
            .padding(.horizontal, FocusPanelSpacing.md)
            .frame(width: FocusPanelControl.pickerWidth, height: FocusPanelControl.fieldHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusPanelFieldSurface(cornerRadius: FocusPanelCornerRadius.large)
        .accessibilityIdentifier(FocusTimerAccessibilityID.SettingsPopover.categoryPicker)
        .popover(
            isPresented: $isPresented,
            attachmentAnchor: .point(.bottom),
            arrowEdge: .top
        ) {
            CategoryPickerPopoverContent(
                availableTags: availableTags,
                selectedTagName: selectedTagName,
                untaggedTitle: FocusTagCatalog.untaggedName,
                onSelectTag: onSelectTag,
                onCreateTag: onCreateTag,
                onRenameTag: onRenameTag,
                onDeleteTag: onDeleteTag
            )
        }
    }
}

private struct CategoryPickerPopoverContent: View {
    let availableTags: [String]
    let selectedTagName: String?
    let untaggedTitle: String
    let onSelectTag: (String?) -> Void
    let onCreateTag: () -> Void
    let onRenameTag: (String) -> Void
    let onDeleteTag: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FocusPanelSpacing.xs) {
            Button(action: { onSelectTag(nil) }) {
                pickerRowLabel(title: untaggedTitle, isSelected: selectedTagName == nil)
            }
            .buttonStyle(.plain)

            if !availableTags.isEmpty {
                Divider()
                    .padding(.vertical, FocusPanelSpacing.xxs)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: FocusPanelSpacing.xxs) {
                        ForEach(availableTags, id: \.self) { tag in
                            CategoryPickerTagRowView(
                                title: tag,
                                isSelected: selectedTagName == tag,
                                accessibilityIdentifier: "categoryPicker.row.\(tag)",
                                onSelect: { onSelectTag(tag) },
                                onRename: { onRenameTag(tag) },
                                onDelete: { onDeleteTag(tag) }
                            )
                            .frame(height: FocusPanelControl.compactRowHeight)
                        }
                    }
                }
                .frame(maxHeight: min(CGFloat(availableTags.count) * 34, 180))
            }

            Divider()
                .padding(.top, FocusPanelSpacing.xxs)

            Button(action: onCreateTag) {
                FocusSelectableRow {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                    Text("新建分类")
                    Spacer(minLength: 0)
                }
                .font(FocusPanelTypography.bodyLabel)
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(FocusPanelSpacing.md)
        .frame(width: FocusPanelControl.pickerPopoverWidth)
    }

    private func pickerRowLabel(title: String, isSelected: Bool) -> some View {
        FocusSelectableRow(isSelected: isSelected) {
            HStack(spacing: FocusPanelSpacing.sm) {
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
        }
        .font(FocusPanelTypography.bodyLabel)
        .foregroundColor(.primary)
    }
}

struct CategoryPickerTagRowView: NSViewRepresentable {
    let title: String
    let isSelected: Bool
    let accessibilityIdentifier: String?
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onSelect: onSelect,
            onRename: onRename,
            onDelete: onDelete
        )
    }

    func makeNSView(context: Context) -> CategoryPickerTagRowControl {
        let view = CategoryPickerTagRowControl()
        if let accessibilityIdentifier {
            view.identifier = NSUserInterfaceItemIdentifier(accessibilityIdentifier)
        }
        view.coordinator = context.coordinator
        view.title = title
        view.isSelected = isSelected
        return view
    }

    func updateNSView(_ nsView: CategoryPickerTagRowControl, context: Context) {
        context.coordinator.onSelect = onSelect
        context.coordinator.onRename = onRename
        context.coordinator.onDelete = onDelete
        nsView.coordinator = context.coordinator
        nsView.title = title
        nsView.isSelected = isSelected
    }

    final class Coordinator: NSObject {
        var onSelect: () -> Void
        var onRename: () -> Void
        var onDelete: () -> Void

        init(
            onSelect: @escaping () -> Void,
            onRename: @escaping () -> Void,
            onDelete: @escaping () -> Void
        ) {
            self.onSelect = onSelect
            self.onRename = onRename
            self.onDelete = onDelete
        }

        func showContextMenu(from view: NSView) {
            let menu = makeContextMenu()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.maxY - 2), in: view)
        }

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu()
            menu.addItem(menuItem(title: "重命名分类…") { [weak self] in
                self?.onRename()
            })
            menu.addItem(menuItem(title: "删除分类") { [weak self] in
                self?.onDelete()
            })
            return menu
        }

        @objc
        private func handleMenuItem(_ sender: NSMenuItem) {
            (sender.representedObject as? CategoryPickerMenuAction)?.handler()
        }

        private func menuItem(title: String, handler: @escaping () -> Void) -> NSMenuItem {
            let item = NSMenuItem(title: title, action: #selector(handleMenuItem(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = CategoryPickerMenuAction(handler: handler)
            return item
        }
    }
}

final class CategoryPickerTagRowControl: NSControl {
    weak var coordinator: CategoryPickerTagRowView.Coordinator?
    private let titleField = NSTextField(labelWithString: "")
    private let checkmarkImageView = NSImageView()

    var title: String = "" {
        didSet {
            titleField.stringValue = title
        }
    }

    var isSelected: Bool = false {
        didSet {
            updateSelectionState()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            coordinator?.showContextMenu(from: self)
            return
        }

        coordinator?.onSelect()
    }

    override func rightMouseDown(with event: NSEvent) {
        coordinator?.showContextMenu(from: self)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        coordinator?.makeContextMenu()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = FocusPanelCornerRadius.small
        layer?.masksToBounds = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.cell?.wraps = false
        titleField.cell?.isScrollable = true
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
        checkmarkImageView.contentTintColor = .controlAccentColor
        checkmarkImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(titleField)
        addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: checkmarkImageView.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            checkmarkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 10),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 10)
        ])

        updateSelectionState()
    }

    private func updateSelectionState() {
        layer?.backgroundColor = (
            isSelected ? FocusPanelNSColor.selectionFill : FocusPanelNSColor.rowFill
        ).cgColor
        checkmarkImageView.isHidden = !isSelected
    }
}

private final class CategoryPickerMenuAction: NSObject {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }
}

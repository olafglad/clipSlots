import ClipSlotsCore
import SwiftUI
import UniformTypeIdentifiers

struct PopoverView: View {
    @ObservedObject var model: SlotsModel

    var body: some View {
        Group {
            if let n = model.peekSlot, let item = model.slot(n), !item.isEmpty {
                PeekView(model: model, item: item)
            } else {
                SlotListView(model: model)
            }
        }
        .frame(width: 400)
        .background(Theme.background)
        .foregroundColor(Theme.text)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - List

struct SlotListView: View {
    @ObservedObject var model: SlotsModel
    @FocusState private var filterFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.border)
            filterField
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)
            SectionHeader(title: "Slots", trailing: countText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            VStack(spacing: 2) {
                ForEach(model.visibleSlots) { item in
                    SlotRowView(model: model, item: item)
                }
                if model.visibleSlots.isEmpty {
                    Text("no slots match “\(model.filter)”")
                        .font(Theme.mono(12))
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 8)

            strip
            Divider().overlay(Theme.border)
            footer
        }
        .onAppear { filterFocused = true }
    }

    private var countText: String {
        let q = model.filter.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            let c = model.visibleSlots.count
            return "\(c) match\(c == 1 ? "" : "es")"
        }
        return "\(model.usedCount) used · \(model.slotCount - model.usedCount) free"
    }

    private var header: some View {
        HStack(spacing: 12) {
            if let mascot = Mascot.image {
                Image(nsImage: mascot)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .padding(.vertical, -4)
                    .padding(.trailing, -2)
                    .accessibilityLabel("ClipSlots octopus mascot")
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("clipslots")
                        .font(Theme.mono(15, .bold))
                    Text("v\(model.version)")
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textTertiary)
                }
                if model.accessibilityGranted {
                    HStack(spacing: 6) {
                        Text("●").foregroundColor(Theme.mint)
                        Text("hotkeys active · \(model.usedCount)/\(model.slotCount) slots")
                            .foregroundColor(Theme.textSecondary)
                    }
                    .font(Theme.mono(11))
                } else {
                    Button(action: model.showOnboarding) {
                        HStack(spacing: 6) {
                            Text("○").foregroundColor(Theme.danger)
                            Text("accessibility needed · set up")
                                .underline()
                                .foregroundColor(Theme.danger)
                        }
                        .font(Theme.mono(11))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            settingsMenu
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        // The header is the panel's handle: drag it anywhere, and it
        // reopens in that spot next time.
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { _ in model.panelDragChanged() }
                .onEnded { _ in model.panelDragEnded() }
        )
        .onHover { inside in
            if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
        }
        .help("Drag to move")
    }

    private var settingsMenu: some View {
        Menu {
            Toggle("Start at login", isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
            Button("Edit config file…") { model.openConfigFile() }
            Button("Move back under the menubar icon") { model.resetPanelPosition() }
            if !model.accessibilityGranted {
                Button("Accessibility setup…") { model.showOnboarding() }
            }
            Divider()
            Button("About ClipSlots") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
            Button("Quit ClipSlots") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.text.opacity(0.75))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 32, height: 32)
        .accessibilityLabel("Settings")
    }

    private var filterField: some View {
        HStack(spacing: 10) {
            Text("❯")
                .font(Theme.mono(13, .bold))
                .foregroundColor(Theme.mint)
            Text("grep")
                .font(Theme.mono(13))
                .foregroundColor(Theme.accentLight)
            TextField("filter slots…", text: $model.filter)
                .textFieldStyle(.plain)
                .font(Theme.mono(13))
                .foregroundColor(Theme.text)
                .focused($filterFocused)
                .accessibilityLabel("Filter slots")
            KeyCombo(["⌘", "F"])
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Theme.border, lineWidth: 1))
        .onReceive(NotificationCenter.default.publisher(for: .clipSlotsFocusFilter)) { _ in
            filterFocused = true
        }
    }

    @ViewBuilder
    private var strip: some View {
        if let target = model.dropTarget, let source = model.dragSource {
            let empty = model.slot(target)?.isEmpty ?? false
            let verb = model.dropIsCopy ? "copy" : (empty ? "move" : "swap")
            let arrow = (model.dropIsCopy || empty) ? "→" : "↔"
            StatusStrip(
                text: Text("\(verb) ") + Text("\(source)").foregroundColor(Theme.accentLighter).bold()
                    + Text(" \(arrow) ") + Text("\(target)").foregroundColor(Theme.mint).bold()
                    + Text(" · release to drop").foregroundColor(Theme.textSecondary),
                trailing: model.dropIsCopy ? nil : "hold ⌥ to copy"
            )
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        } else if let toast = model.toast {
            StatusStrip(text: Text(toast.text), tint: toast.kind == .success ? Theme.mint : Theme.danger)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
    }

    private var footer: some View {
        let selectedItem = model.slot(model.selected)
        let canUndo = selectedItem?.canUndo ?? false
        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                KeyCombo(pattern: model.keybinds.paste, slots: model.slotCount)
                Text("paste")
                Text("·").foregroundColor(Theme.textTertiary)
                KeyCombo(pattern: model.keybinds.save, slots: model.slotCount)
                Text("save")
            }
            .font(Theme.mono(11))
            .foregroundColor(Theme.textSecondary)
            .lineLimit(1)
            .fixedSize()
            Spacer(minLength: 0)
            Button {
                model.undo(model.selected)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                    Text("undo \(model.selected)")
                    KeyCombo(["⌘", "Z"]).opacity(canUndo ? 1 : 0.6)
                }
                .font(Theme.mono(11))
                .foregroundColor(canUndo ? Theme.text.opacity(0.85) : Theme.textTertiary)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canUndo)
            .help(canUndo ? "Restore slot \(model.selected)'s previous content" : "Nothing to undo in slot \(model.selected)")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
    }
}

extension Notification.Name {
    static let clipSlotsFocusFilter = Notification.Name("clipSlotsFocusFilter")
}

// MARK: - Row

struct SlotRowView: View {
    @ObservedObject var model: SlotsModel
    let item: SlotItem
    @State private var hovering = false

    private var isSelected: Bool { model.selected == item.number }
    private var isDropTarget: Bool { model.dropTarget == item.number && model.dragSource != item.number }
    private var isDragSource: Bool { model.dragSource == item.number && model.dropTarget != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A tap gesture rather than a Button: on macOS a Button swallows
            // the mouse-down, and the row's .onDrag would never start.
            rowContent
                .onTapGesture { model.select(item.number) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { model.select(item.number) }

            if isSelected && !isDropTarget {
                actions
                    .padding(.leading, 48)
                    .padding(.trailing, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, style: StrokeStyle(lineWidth: isDropTarget ? 1.5 : 1, dash: isDropTarget ? [5, 3] : []))
        )
        .opacity(isDragSource ? 0.45 : 1)
        .onHover { hovering = $0 }
        .onDrag {
            model.dragSource = item.number
            model.select(item.number)
            return NSItemProvider(object: "clipslots-slot:\(item.number)" as NSString)
        }
        .onDrop(of: [UTType.plainText], delegate: SlotDropDelegate(target: item.number, model: model))
        .contextMenu { contextMenu }
    }

    private var background: Color {
        if isDropTarget { return Theme.mint.opacity(0.08) }
        if isSelected { return Theme.selectionFill }
        if hovering { return Theme.text.opacity(0.05) }
        return .clear
    }

    private var borderColor: Color {
        if isDropTarget { return Theme.mint }
        if isSelected { return Theme.selectionBorder }
        return .clear
    }

    private var accessibilityText: String {
        var parts = ["Slot \(item.number)"]
        if let label = item.label { parts.append(label) }
        parts.append(item.isEmpty ? "empty" : item.summary)
        if item.locked { parts.append("locked") }
        return parts.joined(separator: ", ")
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            Keycap(number: item.number, empty: item.isEmpty, highlighted: isDropTarget)
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                if let label = item.label, !item.isEmpty {
                    Text(label)
                        .font(Theme.mono(12, .semibold))
                        .foregroundColor(Theme.mint)
                        .lineLimit(1)
                }
                if item.isEmpty {
                    HStack(spacing: 6) {
                        Text("empty ·")
                        KeyCombo(pattern: model.engine.config.expandKeybind(model.keybinds.save, slot: item.number), slots: 1, compact: true)
                        Text("saves here")
                    }
                    .font(Theme.mono(12.5))
                    .foregroundColor(summaryColor)
                    .lineLimit(1)
                } else {
                    Text(item.summary)
                        .font(Theme.mono(12.5))
                        .foregroundColor(summaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 0)
            if isDropTarget {
                Text(model.dropIsCopy ? "copy" : (item.isEmpty ? "move" : "⇅ swap"))
                    .font(Theme.mono(11, .bold))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Theme.mint))
            } else {
                HStack(spacing: 6) {
                    if item.locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.accentLight)
                            .accessibilityLabel("Locked")
                    }
                    Text(AgeText.short(since: item.updatedAt))
                        .font(Theme.mono(11))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    private var summaryColor: Color {
        if item.isEmpty { return Theme.textTertiary }
        if item.kind == .link { return Theme.link }
        return Theme.text
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.kind == .image, let image = item.image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 34, height: 34)
                .background(Theme.thumb)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.border, lineWidth: 1))
        } else {
            Image(systemName: item.kind.symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(item.isEmpty ? Theme.text.opacity(0.45) : Theme.text.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
        }
    }

    @ViewBuilder
    private var actions: some View {
        if item.isEmpty {
            FlowLayout {
                ActionButton(title: "Save clipboard here", symbol: "arrow.down.to.line", primary: true) {
                    model.saveClipboard(into: item.number)
                }
            }
        } else {
            FlowLayout {
                ActionButton(title: "Copy", symbol: "doc.on.doc", hint: "⏎", primary: true) {
                    model.copy(item.number)
                }
                ActionButton(title: "Paste", symbol: "doc.on.clipboard") {
                    model.paste(item.number)
                }
                if let openLabel = item.openLabel {
                    ActionButton(title: openLabel, symbol: item.kind == .image ? "eye" : "arrow.up.right.square") {
                        model.open(item.number)
                    }
                }
                ActionButton(title: item.locked ? "Unlock" : "Lock", symbol: item.locked ? "lock.open" : "lock") {
                    model.toggleLock(item.number)
                }
                ActionButton(title: nil, symbol: "tag", accessibilityLabel: "Edit label") {
                    model.editLabel(item.number)
                }
                if !item.locked {
                    ActionButton(title: nil, symbol: "trash", accessibilityLabel: "Clear slot") {
                        model.clear(item.number)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var contextMenu: some View {
        if item.isEmpty {
            Button("Save clipboard here") { model.saveClipboard(into: item.number) }
        } else {
            Button("Copy") { model.copy(item.number) }
            Button("Paste") { model.paste(item.number) }
            Button("Peek") { model.peekSlot = item.number }
            Divider()
            Button(item.locked ? "Unlock" : "Lock") { model.toggleLock(item.number) }
            if item.canUndo { Button("Undo last change") { model.undo(item.number) } }
            if !item.locked { Button("Clear") { model.clear(item.number) } }
        }
    }
}

struct SlotDropDelegate: DropDelegate {
    let target: Int
    let model: SlotsModel

    func validateDrop(info: DropInfo) -> Bool {
        model.dragSource != nil
    }

    func dropEntered(info: DropInfo) {
        guard let source = model.dragSource, source != target else { return }
        model.dropTarget = target
        model.dropIsCopy = NSEvent.modifierFlags.contains(.option)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        let copy = NSEvent.modifierFlags.contains(.option)
        if model.dropIsCopy != copy { model.dropIsCopy = copy }
        return DropProposal(operation: copy ? .copy : .move)
    }

    func dropExited(info: DropInfo) {
        if model.dropTarget == target { model.dropTarget = nil }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let source = model.dragSource else { return false }
        model.drop(from: source, onto: target, copy: NSEvent.modifierFlags.contains(.option))
        return true
    }
}

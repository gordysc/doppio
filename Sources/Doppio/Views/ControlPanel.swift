import DoppioCore
import SwiftUI

/// The main controls: on/off switch, what to keep awake, for how long, and
/// the resulting command line. Shown in both the menu bar popover and the window.
///
/// SwiftUI views are lightweight `struct`s that *describe* UI. SwiftUI calls
/// `body` again whenever observed data it read changes, then compares the new
/// description with the old and updates only what differs. Recomputing
/// `body` often is normal and cheap.
struct ControlPanel: View {
    /// The shared model. A plain `let` is enough: because `AppModel` is
    /// `@Observable`, reading its properties in `body` already subscribes this
    /// view to changes. No `@ObservedObject` wrapper is needed (that was the
    /// older `ObservableObject` approach).
    let model: AppModel

    /// The view's content, top to bottom.
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader(model: model)
            Divider()
            PanelSection(title: "Keep awake") {
                AssertionList(model: model)
            }
            PanelSection(title: "Duration") {
                LimitEditor(model: model)
            }
            CommandPreview(model: model)
        }
    }
}

/// A titled group of controls with a small uppercase heading.
///
/// `Content: View` is a *generic parameter*: the section can wrap any view
/// type, and the compiler knows the exact type, which keeps SwiftUI fast.
private struct PanelSection<Content: View>: View {
    /// The heading text.
    let title: String
    /// The wrapped controls.
    ///
    /// `@ViewBuilder` lets callers pass several views in a trailing closure,
    /// as `VStack { ... }` does, instead of one view.
    @ViewBuilder let content: Content

    /// The heading above the content.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
    }
}

/// The app name, live status, and the main on/off switch.
private struct StatusHeader: View {
    /// The shared model.
    let model: AppModel

    /// Icon, title with status, and the switch.
    var body: some View {
        let isActive = model.session.isActive
        HStack(spacing: 10) {
            Image(systemName: isActive ? "cup.and.heat.waves.fill" : "cup.and.saucer")
                .font(.title2)
                .foregroundStyle(isActive ? Color.orange : Color.secondary)
                // A fixed frame stops the text shifting when the symbol changes width.
                .frame(width: 30)
                // Cross-fade between the two symbols instead of an abrupt swap.
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text("Doppio").font(.headline)
                Text(model.statusLine)
                    .font(.caption)
                    .foregroundStyle(model.session.lastError == nil ? Color.secondary : Color.red)
                    // Monospaced digits stop the countdown jittering as numbers change width.
                    .monospacedDigit()
            }
            Spacer()
            // `Toggle` wants a `Binding<Bool>`: a read/write handle to some
            // state. We build one by hand so that writing calls the model's
            // method (which starts or stops `caffeinate`) rather than
            // just flipping a stored Bool.
            Toggle("Keep awake", isOn: Binding(
                get: { model.session.isActive },
                set: { model.setActive($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            // Can't turn on with incomplete settings, but can always turn off.
            .disabled(!isActive && !model.canStart)
        }
    }
}

/// One checkbox per `caffeinate` assertion flag.
private struct AssertionList: View {
    /// The shared model.
    let model: AppModel

    /// The checkboxes, plus a hint when none are checked.
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // `ForEach` over `Identifiable` values builds one row per case and
            // uses `id` to track rows across updates.
            ForEach(Assertion.allCases) { assertion in
                Toggle(isOn: Binding(
                    get: { model.prefs.assertions.contains(assertion) },
                    set: { model.setAssertion(assertion, enabled: $0) }
                )) {
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text(assertion.title)
                            Text("-\(String(assertion.flag))")
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        Text(assertion.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            // Allow wrapping onto more lines instead of truncating.
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.checkbox)
            }
        }
    }
}

/// The duration picker and its kind-specific controls.
private struct LimitEditor: View {
    /// The shared model.
    let model: AppModel

    /// Quick-pick durations, in minutes.
    private let presets = [15, 30, 60, 120, 240, 480]

    /// The segmented kind picker, then the controls for that kind.
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Duration", selection: Binding(
                get: { model.prefs.limitKind },
                set: { model.setLimitKind($0) }
            )) {
                ForEach(LimitKind.allCases) { kind in
                    // `.tag` links each segment to the value the binding receives when it's picked.
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // A `switch` inside a view builder picks which views to show.
            // Only the matching arm's views exist; the others are removed.
            switch model.prefs.limitKind {
            case .indefinite:
                hint("The Mac stays awake until you turn it off.")
            case .duration:
                durationControls
            case .untilTime:
                untilControls
            case .whileAppRuns:
                appControls
            }
        }
    }

    /// Preset chips plus a stepper for a custom number of minutes.
    private var durationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            // A 3-column grid. `.flexible()` columns share the width equally.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                // `id: \.self` uses each number as its own identity; fine here
                // because the presets are unique.
                ForEach(presets, id: \.self) { minutes in
                    Button(DurationText.short(minutes: minutes)) {
                        model.setDuration(minutes: minutes)
                    }
                    .buttonStyle(ChipButtonStyle(isSelected: model.prefs.durationMinutes == minutes))
                }
            }
            Stepper(
                value: Binding(
                    get: { model.prefs.durationMinutes },
                    set: { model.setDuration(minutes: $0) }
                ),
                in: 5...(24 * 60),
                step: 5
            ) {
                Text("Custom: \(DurationText.short(minutes: model.prefs.durationMinutes))")
                    .monospacedDigit()
            }
        }
    }

    /// A time picker for "stay awake until hh:mm".
    private var untilControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            DatePicker(
                "Stay awake until",
                selection: Binding(
                    // Show the saved time as a `Date` today. Only hour and minute are used.
                    // `bySettingHour` returns an optional (it can fail for
                    // impossible times), so `?? Date()` provides a fallback.
                    get: {
                        Calendar.current.date(
                            bySettingHour: model.prefs.untilHour,
                            minute: model.prefs.untilMinute,
                            second: 0,
                            of: Date()
                        ) ?? Date()
                    },
                    set: { model.setUntilTime($0) }
                ),
                displayedComponents: .hourAndMinute
            )
            hint("If that time is already past today, Doppio uses that time tomorrow.")
        }
    }

    /// A menu of running apps to watch.
    private var appControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // The selection type is `RunningAppChoice?`, so the "none" row
                // is tagged with `nil` (spelled out with its type so it matches)
                // and each app is tagged with an optional wrapping itself.
                Picker("App", selection: Binding(
                    get: { model.targetApp },
                    set: { model.setTargetApp($0) }
                )) {
                    Text("Select an app…").tag(RunningAppChoice?.none)
                    ForEach(model.runningApps) { app in
                        Text(app.name).tag(RunningAppChoice?.some(app))
                    }
                }
                Button {
                    model.refreshRunningApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh the app list")
            }
            hint("The Mac can sleep again when that app quits.")
        }
        // `.onAppear` runs when this view comes on screen, so the list is
        // fresh every time the user switches to this tab.
        .onAppear { model.refreshRunningApps() }
    }

    /// Small secondary text under a control.
    ///
    /// - Parameter text: The hint to show.
    /// - Returns: The styled text view.
    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

/// The exact `caffeinate` command, selectable and copyable.
private struct CommandPreview: View {
    /// The shared model.
    let model: AppModel

    /// The command in a monospaced box, or why nothing can run yet.
    var body: some View {
        // `if let` inside a view builder shows the first branch only when the
        // optional has a value.
        if let blocker = model.startBlocker, !model.session.isActive {
            Label(blocker, systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let command = model.displayedCommand {
            HStack(spacing: 6) {
                Text("$ \(command.commandLine)")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Button {
                    // `NSPasteboard` is AppKit's clipboard. Clear it first, then write.
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command.commandLine, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy command")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            .help("-w connects caffeinate to Doppio. When Doppio stops, caffeinate also stops.")
        }
    }
}

/// A pill-shaped button that shows whether it's the selected option.
///
/// Conforming to `ButtonStyle` means implementing `makeBody`, which receives
/// the button's label and pressed state and returns the styled view. Any
/// `Button` can then adopt it with `.buttonStyle(...)`.
private struct ChipButtonStyle: ButtonStyle {
    /// Whether this chip is the current choice.
    let isSelected: Bool

    /// Draws the label on a rounded background.
    ///
    /// - Parameter configuration: The button's label and pressed state.
    /// - Returns: The styled button.
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(isSelected ? .semibold : .regular))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            )
            // Dim slightly while held down, as feedback.
            .opacity(configuration.isPressed ? 0.7 : 1)
            // Make the whole pill clickable, not just the text.
            .contentShape(RoundedRectangle(cornerRadius: 6))
    }
}

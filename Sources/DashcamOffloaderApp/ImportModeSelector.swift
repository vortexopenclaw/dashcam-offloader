import AppKit
import SwiftUI

struct ImportModeSelector: View {
    @Binding var selection: ImportMode

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ImportMode.allCases) { mode in
                modeButton(mode)
            }
        }
    }

    private func modeButton(_ mode: ImportMode) -> some View {
        let isSelected = selection == mode
        return Button {
            selection = mode
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(mode.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
                        lineWidth: 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("Use " + mode.displayName.lowercased() + " as the import source.")
    }
}

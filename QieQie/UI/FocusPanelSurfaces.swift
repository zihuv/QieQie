import SwiftUI

extension View {
    func focusPanelSurface(cornerRadius: CGFloat = FocusPanelChrome.surfaceCornerRadius) -> some View {
        background(FocusPanelChrome.surfaceFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FocusPanelChrome.surfaceStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    func focusPanelFieldSurface(cornerRadius: CGFloat = FocusPanelCornerRadius.medium) -> some View {
        background(FocusPanelColor.fieldFill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(FocusPanelColor.fieldStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

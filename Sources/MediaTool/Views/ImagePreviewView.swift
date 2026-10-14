import AppKit
import SwiftUI

/// Live before/after preview of the current image settings, driven by the real ImageMagick
/// pipeline. When a watermark is active this doubles as the reposition tool: the logo can be
/// dragged directly on the preview.
struct ImagePreviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var tools: ToolLocator
    @StateObject private var preview = PreviewService()

    @State private var showOriginal = false

    var body: some View {
        Card(title: "Preview", systemImage: "eye") {
            if app.stagedURLs.isEmpty {
                Text("Add an image to see a live preview.")
                    .font(TypeScale.caption)
                    .foregroundColor(Palette.onSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                imageArea

                HStack(spacing: 8) {
                    Chip(
                        text: showOriginal ? "Original" : "Adjusted",
                        foreground: Palette.onSecondaryContainer,
                        fill: Palette.secondaryContainer)

                    if preview.isRendering {
                        Text("Rendering…")
                            .font(TypeScale.caption)
                            .foregroundColor(Palette.onSurfaceVariant)
                    }

                    Spacer()

                    Button(showOriginal ? "Show result" : "Show original") {
                        showOriginal.toggle()
                    }
                    .buttonStyle(TonalButtonStyle())
                }

                if let error = preview.errorMessage {
                    Text(error)
                        .font(TypeScale.monoSmall)
                        .foregroundColor(Palette.error)
                        .lineLimit(2)
                }
            }
        }
        .onAppear { sync() }
        .onChange(of: app.stagedURLs) { _ in sync() }
        .onChange(of: app.image) { _ in requestRender() }
    }

    @ViewBuilder private var imageArea: some View {
        let shown = showOriginal ? preview.original : (preview.rendered ?? preview.original)
        ZStack {
            Palette.surfaceVariant
            if let shown {
                Image(nsImage: shown)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .padding(6)
                    .overlay {
                        // Drag handle sits on top of the rendered result, matching its frame.
                        if !showOriginal, dragEnabled {
                            WatermarkDragLayer(
                                imageSize: shown.size,
                                settings: $app.image.watermark
                            )
                            .padding(6)
                        }
                    }
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.controlRadius, style: .continuous)
                .strokeBorder(Palette.outlineVariant, lineWidth: Metrics.hairline)
        )
        // Dim slightly while a fresh render is in flight so stale output is obvious.
        .opacity(preview.isRendering && !showOriginal ? 0.55 : 1)
        .animation(.easeOut(duration: 0.15), value: preview.isRendering)
    }

    private var dragEnabled: Bool {
        app.image.watermark.enabled && !app.image.watermark.logoPath.isEmpty
    }

    /// Points the preview at the first staged image and renders it.
    private func sync() {
        preview.setSource(app.stagedURLs.first)
        requestRender()
    }

    private func requestRender() {
        preview.requestRender(
            settings: app.image,
            magickPath: tools.tools.magick,
            watermark: app.stagedURLs.first.flatMap(app.watermarkPlacement(for:)))
    }
}

// MARK: - Drag layer

/// Transparent overlay that maps drags onto the watermark's normalised position.
///
/// The preview image is `scaledToFit`, so the drawn image rarely fills the container — the fitted
/// rect has to be recomputed here or the handle drifts away from the logo it represents.
struct WatermarkDragLayer: View {
    /// Pixel size of the rendered preview image, used for its aspect ratio.
    let imageSize: CGSize
    @Binding var settings: WatermarkSettings

    @State private var dragOrigin: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let fitted = fittedRect(in: geo.size)
            let handle = handleSize(in: fitted)
            let free = CGSize(
                width: max(fitted.width - handle.width, 0),
                height: max(fitted.height - handle.height, 0))
            let origin = CGPoint(
                x: fitted.minX + free.width * clamp(settings.normX),
                y: fitted.minY + free.height * clamp(settings.normY)
            )

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Palette.primary.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Palette.primary, lineWidth: 2)
                )
                .overlay(alignment: .topLeading) {
                    Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Palette.onPrimary)
                        .padding(3)
                        .background(Circle().fill(Palette.primary))
                }
                .frame(width: handle.width, height: handle.height)
                .position(
                    x: origin.x + handle.width / 2,
                    y: origin.y + handle.height / 2
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = dragOrigin ?? origin
                            if dragOrigin == nil { dragOrigin = origin }
                            let moved = CGPoint(
                                x: start.x + value.translation.width,
                                y: start.y + value.translation.height)
                            if free.width > 0 {
                                settings.normX = clamp((moved.x - fitted.minX) / free.width)
                            }
                            if free.height > 0 {
                                settings.normY = clamp((moved.y - fitted.minY) / free.height)
                            }
                        }
                        .onEnded { _ in dragOrigin = nil }
                )
                .help("Drag to reposition the watermark")
        }
    }

    /// Where the aspect-fitted image actually sits inside the container.
    private func fittedRect(in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: container)
        }
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = container.width / max(container.height, 1)

        var size = container
        if imageAspect > containerAspect {
            size.height = container.width / imageAspect
        } else {
            size.width = container.height * imageAspect
        }
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height)
    }

    /// The logo's on-screen size: its width is a percentage of the image width, and its height
    /// follows from the *logo's* own aspect ratio.
    private func handleSize(in fitted: CGRect) -> CGSize {
        let width = fitted.width * settings.scalePercent / 100
        var aspect: CGFloat = 1
        if let url = settings.logoURL, let px = AppState.pixelSize(of: url), px.height > 0 {
            aspect = CGFloat(px.width) / CGFloat(px.height)
        }
        return CGSize(width: width, height: width / max(aspect, 0.01))
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
    private func clamp(_ value: CGFloat) -> Double { min(max(Double(value), 0), 1) }
}

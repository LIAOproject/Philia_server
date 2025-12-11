//
//  ImageCropperSheet.swift
//  Philia
//
//  Circular image cropper for avatar selection
//

import SwiftUI

struct ImageCropperSheet: View {
    let image: UIImage
    let onCropped: (Data) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropSize: CGFloat = 280

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    Color.black.ignoresSafeArea()

                    // Image with gestures
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )

                    // Overlay mask with circular cutout
                    CropOverlay(cropSize: cropSize, screenSize: geometry.size)

                    // Circular border
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: cropSize, height: cropSize)
                }
            }
            .navigationTitle("裁剪头像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        cropImage()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func cropImage() {
        // Calculate the crop rect based on current scale and offset
        let imageSize = image.size
        let screenScale = UIScreen.main.scale

        // Calculate the visible portion
        let imageAspect = imageSize.width / imageSize.height
        let viewWidth: CGFloat = UIScreen.main.bounds.width
        let viewHeight: CGFloat = UIScreen.main.bounds.height

        var displayWidth: CGFloat
        var displayHeight: CGFloat

        if imageAspect > viewWidth / viewHeight {
            displayWidth = viewWidth
            displayHeight = viewWidth / imageAspect
        } else {
            displayHeight = viewHeight
            displayWidth = viewHeight * imageAspect
        }

        displayWidth *= scale
        displayHeight *= scale

        // Calculate crop center in view coordinates
        let centerX = viewWidth / 2 - offset.width
        let centerY = viewHeight / 2 - offset.height

        // Convert to image coordinates
        let imageX = (centerX - (viewWidth - displayWidth) / 2) / displayWidth * imageSize.width
        let imageY = (centerY - (viewHeight - displayHeight) / 2) / displayHeight * imageSize.height

        // Crop size in image coordinates
        let cropSizeInImage = cropSize / displayWidth * imageSize.width

        // Create crop rect
        let cropRect = CGRect(
            x: imageX - cropSizeInImage / 2,
            y: imageY - cropSizeInImage / 2,
            width: cropSizeInImage,
            height: cropSizeInImage
        )

        // Perform crop
        if let croppedCGImage = image.cgImage?.cropping(to: cropRect) {
            let croppedImage = UIImage(cgImage: croppedCGImage)

            // Create circular mask
            let size = CGSize(width: 256, height: 256)
            UIGraphicsBeginImageContextWithOptions(size, false, screenScale)

            let context = UIGraphicsGetCurrentContext()!
            context.addEllipse(in: CGRect(origin: .zero, size: size))
            context.clip()

            croppedImage.draw(in: CGRect(origin: .zero, size: size))

            let circularImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            if let data = circularImage?.pngData() {
                onCropped(data)
            }
        }

        dismiss()
    }
}

// MARK: - Crop Overlay

struct CropOverlay: View {
    let cropSize: CGFloat
    let screenSize: CGSize

    var body: some View {
        Canvas { context, size in
            // Fill entire area with semi-transparent black
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(.black.opacity(0.6))
            )

            // Cut out circle in center
            let circleRect = CGRect(
                x: (size.width - cropSize) / 2,
                y: (size.height - cropSize) / 2,
                width: cropSize,
                height: cropSize
            )

            context.blendMode = .destinationOut
            context.fill(
                Path(ellipseIn: circleRect),
                with: .color(.white)
            )
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    ImageCropperSheet(image: UIImage(systemName: "person.fill")!) { _ in }
}

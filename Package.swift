// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "IconPreviewLabNative",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "IconPreviewLabNative",
      targets: ["IconPreviewLabNative"]
    )
  ],
  targets: [
    .executableTarget(
      name: "IconPreviewLabNative",
      resources: [
        .copy("Resources")
      ]
    )
  ]
)

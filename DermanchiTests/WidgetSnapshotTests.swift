import SwiftUI
import XCTest
@testable import Dermanchi

/// README üçün widget şəkillərini real widget görünüşlərindən render edir.
///
///     TEST_RUNNER_SNAPSHOT_DIR=/path/to/docs/screenshots xcodebuild test ... \
///       -only-testing:DermanchiTests/WidgetSnapshotTests
///
/// `SNAPSHOT_DIR` verilməyibsə test ötürülür.
@MainActor
final class WidgetSnapshotTests: XCTestCase {
    private var outputDir: URL!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("SNAPSHOT_DIR verilməyib")
        }
        outputDir = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    /// Sabit an: 17:08 — növbəti damcı 18:00 Xiloial (52 dəq), ondan sonra 19:00 Moxi-R.
    private var entry: DoseEntry {
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 17, minute: 8))!
        return DoseEntry(date: now, state: .preview(at: now))
    }

    func testRenderHomeWidgets() throws {
        try render(homeWidget(SmallView(entry: entry), size: CGSize(width: 170, height: 170)),
                   name: "widget-small.png")
        try render(homeWidget(MediumView(entry: entry), size: CGSize(width: 364, height: 170)),
                   name: "widget-medium.png")
    }

    func testRenderLockScreenWidget() throws {
        let lock = LockRectangularView(entry: entry)
            .frame(width: 172, height: 76)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .foregroundStyle(.white)
            .environment(\.colorScheme, .dark)
            .padding(.vertical, 26)
            .padding(.horizontal, 28)
            .background(
                LinearGradient(colors: [Color(red: 0.10, green: 0.14, blue: 0.22),
                                        Color(red: 0.04, green: 0.06, blue: 0.11)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .padding(20)
        try render(lock, name: "widget-lock.png")
    }

    // MARK: - Köməkçilər

    private func homeWidget<V: View>(_ view: V, size: CGSize) -> some View {
        view
            .padding(16)
            .frame(width: size.width, height: size.height)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .environment(\.colorScheme, .light)
            .shadow(color: .black.opacity(0.18), radius: 14, y: 5)
            .padding(20)
    }

    private func render<V: View>(_ view: V, name: String) throws {
        let renderer = ImageRenderer(content: view.environment(\.locale, Locale(identifier: "az_AZ")))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, "\(name) render olunmadı")
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: outputDir.appending(path: name))
    }
}

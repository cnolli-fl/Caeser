import AppKit
import SwiftUI
import Testing
@testable import Caeser

@Suite(.serialized)
@MainActor
struct WhatsNewTests {
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "Caeser-UITests-whats-new-\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test func firstLaunchIsRequestedOnlyOncePerSession() throws {
        try withDefaults { defaults in
            let model = WhatsNewModel(defaults: defaults, version: "3.1.1")
            #expect(model.requestAutomaticPresentation())
            #expect(!model.requestAutomaticPresentation())
        }
    }

    @Test func closingAndReopeningSameVersionDoesNotShowAgain() throws {
        try withDefaults { defaults in
            let first = WhatsNewModel(defaults: defaults, version: "3.1.1")
            first.markPresented()
            #expect(!WhatsNewModel(defaults: defaults, version: "3.1.1").requestAutomaticPresentation())
        }
    }

    @Test func updateShowsNewVersionAndDowngradeDoesNotRepeat() throws {
        try withDefaults { defaults in
            WhatsNewModel(defaults: defaults, version: "3.1.0").markPresented()
            let updated = WhatsNewModel(defaults: defaults, version: "3.1.1")
            #expect(updated.requestAutomaticPresentation())
            updated.markPresented()
            let downgraded = WhatsNewModel(defaults: defaults, version: "3.1.0")
            #expect(!downgraded.requestAutomaticPresentation())
            downgraded.markPresented()
            #expect(!WhatsNewModel(defaults: defaults, version: "3.1.1").requestAutomaticPresentation())
        }
    }

    @Test func notesAreMarkedOnlyAfterTheyActuallyAppear() throws {
        try withDefaults { defaults in
            #expect(WhatsNewModel(defaults: defaults, version: "3.1.1").requestAutomaticPresentation())
            #expect(WhatsNewModel(defaults: defaults, version: "3.1.1").requestAutomaticPresentation())
        }
    }

    @Test func manualReopeningPreservesLibraryAndPreferences() throws {
        try withDefaults { defaults in
            let library = Data("existing history".utf8)
            defaults.set(library, forKey: "downloadLibrary.v1")
            defaults.set("/a/pasta", forKey: "destination")
            let model = WhatsNewModel(defaults: defaults, version: "3.1.1")
            model.markPresented()
            model.markPresented()
            #expect(model.highlights.items.count == 3)
            #expect(defaults.data(forKey: "downloadLibrary.v1") == library)
            #expect(defaults.string(forKey: "destination") == "/a/pasta")
        }
    }

    @Test func unknownReleaseHasNoStaleFeaturesAndInvalidVersionDoesNotOpen() throws {
        try withDefaults { defaults in
            let future = WhatsNewModel(defaults: defaults, version: "3.2.0")
            #expect(future.highlights.items.count == 1)
            #expect(future.highlights.pageURL.absoluteString == "https://github.com/cnolli-fl/Caeser/releases/tag/v3.2.0")
            #expect(!WhatsNewModel(defaults: defaults, version: "invalid").requestAutomaticPresentation())
        }
    }

    @Test func notesFitTheDefaultWindow() throws {
        try withDefaults { defaults in
            let view = NSHostingView(rootView: WhatsNewView(model: WhatsNewModel(defaults: defaults, version: "3.1.1")))
            let size = view.fittingSize
            #expect(size.width >= 480 && size.width <= 600)
            #expect(size.height >= 440 && size.height <= 600)
        }
    }
}

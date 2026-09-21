import Foundation
#if canImport(CoreText)
import CoreText
#endif

/// Xcode's synchronized resource groups can flatten or preserve `Resources/`
/// subfolders depending on the build action. Register the shipped display and
/// UI fonts explicitly so editorial type never silently falls back to San
/// Francisco in an archive or simulator capture.
enum StillFontRegistration {
    private static let resources = [
        "InstrumentSerif-Regular.ttf",
        "InstrumentSerif-Italic.ttf",
        "Outfit-Regular.ttf",
        "Outfit-Medium.ttf",
        "Outfit-SemiBold.ttf"
    ]

    static func registerBundledFonts() {
        #if canImport(CoreText)
        for resource in resources {
            let stem = (resource as NSString).deletingPathExtension
            let ext = (resource as NSString).pathExtension
            let url = Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: stem, withExtension: ext, subdirectory: "Resources/Fonts")
                ?? Bundle.main.url(forResource: stem, withExtension: ext)
            guard let url else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        #endif
    }
}

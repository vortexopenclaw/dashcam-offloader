import Foundation

struct KnownDashcamModel: Hashable, Sendable {
    var manufacturer: String
    var model: String
    var aliases: [String]
    var channels: Int?
    var channelRoles: [String]
    var channelResolutions: [String: String]
    var channelSensors: [String: String]
    var sensorNotes: [String]
    var parkingModes: [String]
    var notes: String

    var displayName: String {
        "\(manufacturer) \(model)"
    }

    var searchNames: [String] {
        [model, displayName] + aliases
    }
}

/// Internal model knowledge used for learning prefill and future candidate
/// hints. Entries here are not supported camera profiles.
enum KnownDashcamCatalog {
    private static let submittedManualChoiceKeys: Set<String> = [
        "miofive|s1ultra",
        "wolfbox|g900pro"
    ]

    static func hasSubmittedCardScan(_ model: KnownDashcamModel) -> Bool {
        submittedManualChoiceKeys.contains("\(compact(model.manufacturer))|\(compact(model.model))")
    }

    private static let genericVolumeLabels: Set<String> = [
        "blackvue",
        "dashcam",
        "dcim",
        "disk",
        "external",
        "no name",
        "noname",
        "sd",
        "sdcard",
        "teslacam",
        "tfcard",
        "untitled",
        "usb",
        "usbdisk",
        "volume"
    ].map { compact($0) }.reduce(into: Set<String>()) { $0.insert($1) }

    static let models: [KnownDashcamModel] = [
        // Vueroid
        model("Vueroid", "H1", channels: 1, roles: ["front"], notes: "Observed card signature H1-QHD-INFINITE."),
        model(
            "Vueroid",
            "S1 4K Infinite",
            aliases: ["S1 4K", "S1-4K", "S1-4K-INF", "S1 4K INF", "S1-4K-INFINITE"],
            channels: 3,
            roles: ["front", "rear", "interior"],
            notes: "Observed 1CH, 2CH, and 3CH S1 4K Infinite card variants."
        ),
        model("Vueroid", "S1 QHD Infinite", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "D40-Q2", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "D21 4K", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "D21 LTE FHD", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "D20-Q2 Plus", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "D20-F2/F2E", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "ZERO", channels: 2, roles: ["front", "rear"]),
        model("Vueroid", "D10-F2W", channels: 2, roles: ["front", "rear"]),

        // VIOFO
        model("VIOFO", "A329S", channels: 3, roles: ["front", "rear", "interior"], notes: "Multiplex video capable."),
        model("VIOFO", "A329T", channels: 3, roles: ["front", "rear", "telephoto"], notes: "Telephoto channel token T observed."),
        model("VIOFO", "A229 Pro", channels: 3, roles: ["front", "rear", "interior"]),
        model("VIOFO", "A229 Plus", channels: 3, roles: ["front", "rear", "interior"]),
        model("VIOFO", "A229 Ultra", channels: 3, roles: ["front", "rear", "interior"]),
        model("VIOFO", "A139 Pro", channels: 3, roles: ["front", "rear", "interior"]),
        model("VIOFO", "T130", channels: 3, roles: ["front", "rear", "interior"]),
        model("VIOFO", "A129 Pro", channels: 2, roles: ["front", "rear"]),
        model("VIOFO", "A129 Plus Duo", channels: 2, roles: ["front", "rear"]),
        model("VIOFO", "A129 Duo", channels: 2, roles: ["front", "rear"]),
        model("VIOFO", "A119M Pro", channels: 1, roles: ["front"]),
        model("VIOFO", "A119 Mini 2", channels: 1, roles: ["front"]),
        model("VIOFO", "A119 V3", aliases: ["A119V3"], channels: 1, roles: ["front"], resolutions: ["front": "2K QHD"]),
        model("VIOFO", "VS1", channels: 1, roles: ["front"]),
        model("VIOFO", "WM1", channels: 1, roles: ["front"]),
        model("VIOFO", "MT1", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"], notes: "Official VIOFO manual/store listing identifies the MT1 as a dual-channel motorcycle dashcam."),
        model("VIOFO", "A329SW", channels: 3, roles: ["front", "rear", "interior"], resolutions: ["front": "4K60", "rear": "2K", "interior": "2K"], notes: "A329S platform with optional waterproof rear and fisheye cabin cameras."),
        model("VIOFO", "A329TC", channels: 3, roles: ["front", "telephoto", "interior"], resolutions: ["front": "4K30", "telephoto": "2K", "interior": "2K"], notes: "A329T platform with telephoto and fisheye cabin cameras."),
        model("VIOFO", "A329TW", channels: 3, roles: ["front", "telephoto", "rear"], resolutions: ["front": "4K30", "telephoto": "2K", "rear": "2K"], notes: "A329T platform with telephoto and waterproof rear cameras."),
        model("VIOFO", "A329WW", channels: 3, roles: ["front", "rear_left", "rear_right"], resolutions: ["front": "4K30", "rear_left": "2K", "rear_right": "2K"], notes: "A329 heavy-duty configuration with dual waterproof rear cameras."),
        model("VIOFO", "A229 Ultra-W", aliases: ["A229ULTRAW"], channels: 3, roles: ["front", "rear", "interior"], resolutions: ["front": "4K", "rear": "4K", "interior": "FHD"], notes: "A229 Ultra platform with waterproof rear option."),
        model("VIOFO", "A229 Pro-W", aliases: ["A229PROW"], channels: 3, roles: ["front", "rear", "interior"], resolutions: ["front": "4K", "rear": "2K", "interior": "FHD"], notes: "A229 Pro platform with waterproof rear option."),
        model("VIOFO", "A229 Plus-W", aliases: ["A229PLUSW"], channels: 3, roles: ["front", "rear", "interior"], resolutions: ["front": "2K", "rear": "2K", "interior": "FHD"], notes: "A229 Plus platform with waterproof rear option."),
        model("VIOFO", "A229 Pro Tele", aliases: ["A229PROTELE"], channels: 3, roles: ["front", "telephoto", "rear"], resolutions: ["front": "4K", "telephoto": "2K", "rear": "FHD"], notes: "A229 Pro configuration with 2K telephoto camera."),

        // Thinkware
        model("Thinkware", "U3000 Pro", aliases: ["U3000PRO"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2K QHD"], notes: "Official U3000 Pro page specifies 4K and 2K dual-channel recording."),
        model("Thinkware", "U3000", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2K QHD"], notes: "Official product listing describes front/rear 4K class recording; prior product documentation distinguishes a 2K rear channel."),
        model("Thinkware", "U1000 Plus", aliases: ["U1000PLUS"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K HDR", "rear": "FHD"], notes: "Official product listing identifies this as a 4K HDR dual dash cam."),
        model("Thinkware", "U1000", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2K QHD"]),
        model("Thinkware", "Q1000", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"]),
        model("Thinkware", "Q850", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"], notes: "Official product listing calls this a 2K QHD dual dash cam."),
        model("Thinkware", "Q800 Pro", aliases: ["Q800PRO"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "FHD"]),
        model("Thinkware", "Q200", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "FHD"], notes: "Official product listing identifies 2K QHD capture; rear resolution is retained as the documented FHD variant."),
        model("Thinkware", "ARC", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"], notes: "ARC-family OSD alone is not an exact model signal."),
        model("Thinkware", "ARC 700", aliases: ["ARC700"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K30, QHD45", "rear": "QHD30"]),
        model("Thinkware", "ARC 800", aliases: ["ARC800"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K30, QHD30, QHD60", "rear": "FHD30"]),
        model("Thinkware", "ARC 900", aliases: ["ARC900"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K30, QHD60", "rear": "QHD30, FHD60"]),
        model("Thinkware", "T700", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "F790", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD HDR", "rear": "FHD HDR"], notes: "Official product listing identifies a 2CH Full HD HDR bundle."),
        model("Thinkware", "F70 Pro", aliases: ["F70PRO"], channels: 1, roles: ["front"], resolutions: ["front": "FHD 1080p"], notes: "Official product listing identifies a 1080p single-channel dash cam."),
        model("Thinkware", "F70", channels: 1, roles: ["front"], resolutions: ["front": "FHD"]),
        model("Thinkware", "F200 Pro", aliases: ["F200PRO"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "F200", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "FA200", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "F800 Pro", aliases: ["F800PRO"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "F800", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "F770", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "F750", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "X1000", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"]),
        model("Thinkware", "X800", channels: 1, roles: ["front"], resolutions: ["front": "2K QHD"]),
        model("Thinkware", "X700", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "X550", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "X500", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "X350", channels: 2, roles: ["front", "rear"], resolutions: ["front": "FHD", "rear": "FHD"]),
        model("Thinkware", "QA100", channels: 2, roles: ["front", "rear"], resolutions: ["front": "QHD", "rear": "QHD"]),
        model("Thinkware", "FA700", channels: 1, roles: ["front"], resolutions: ["front": "FHD"]),
        model("Thinkware", "QN300", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"], notes: "Regional model; catalog hint only until a card is sampled."),
        model("Thinkware", "QN200", aliases: ["QN200LX"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"], notes: "Regional model; catalog hint only until a card is sampled."),
        model("Thinkware", "QN100", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K QHD", "rear": "2K QHD"], notes: "Regional model; catalog hint only until a card is sampled."),
        model("Thinkware", "M1", channels: 2, roles: ["front", "rear"]),

        // BlackVue
        model("BlackVue", "Elite 10", aliases: ["ELITE 10", "ELITE10"], channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "Elite 9", aliases: ["ELITE 9", "ELITE9"], channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "Elite 8", aliases: ["ELITE 8", "ELITE8"], channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "K970X Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "K770X", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X Plus II", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X 2CH LTE Plus II", aliases: ["DR970X-2CH LTE Plus II", "DR970X LTE Plus II"], channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X 2CH IR Plus", aliases: ["DR970X-2CH IR Plus"], channels: 2, roles: ["front", "interior"]),
        model("BlackVue", "DR970X Box 2CH Plus", aliases: ["DR970X-BOX 2CH Plus"], channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X LTE Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X Box Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR970X", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR770X Series II", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR770X", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR770X Box", channels: 3, roles: ["front", "interior", "rear"]),
        model("BlackVue", "DR900X Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR900X", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR900S", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR750X Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR750X 3CH Plus", aliases: ["DR750X-3CH Plus"], channels: 3, roles: ["front", "interior", "rear"]),
        model("BlackVue", "DR750X 2CH LTE Plus", aliases: ["DR750X-2CH LTE Plus"], channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR750X", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR750S", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR650S", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR590X Plus", channels: 2, roles: ["front", "rear"]),
        model("BlackVue", "DR590X", channels: 2, roles: ["front", "rear"]),

        // Vantrue
        model("Vantrue", "Nexus 5S", aliases: ["N5S"], channels: 4, roles: ["front", "rear", "left", "right"]),
        model("Vantrue", "Nexus 5", aliases: ["N5"], channels: 4, roles: ["front", "rear", "left", "right"]),
        model("Vantrue", "N4 Pro S", aliases: ["Nexus 4 Pro S", "N4PROS", "N4 ProS"], channels: 3, roles: ["front", "interior", "rear"], resolutions: ["front": "4K", "interior": "1080p", "rear": "2.5K"], parkingModes: ["collision detection", "motion detection", "low bitrate recording", "low frame rate recording"], notes: "Official page lists 4K front, 1080p cabin, 2.5K rear."),
        model("Vantrue", "Nexus 4 Pro", aliases: ["N4 Pro"], channels: 3, roles: ["front", "interior", "rear"]),
        model("Vantrue", "N4 S", aliases: ["N4S"], channels: 3, roles: ["front", "interior", "rear"]),
        model("Vantrue", "OnDash N4", aliases: ["N4"], channels: 3, roles: ["front", "interior", "rear"]),
        model("Vantrue", "Nexus 2X", aliases: ["N2X"], channels: 2, roles: ["front", "rear"]),
        model("Vantrue", "N2 Pro", channels: 2, roles: ["front", "interior"]),
        model("Vantrue", "N2S", channels: 2, roles: ["front", "interior"]),
        model("Vantrue", "E360 ACE", aliases: ["E360 Ace"], channels: 2, roles: ["panoramic_front", "rear"], notes: "E360 family variants: E360, E360 Plus, E360 ACE. Front/cabin panoramic stream plus optional rear camera."),
        model("Vantrue", "E360 Plus", channels: 2, roles: ["panoramic_front", "rear"]),
        model("Vantrue", "E360", channels: 2, roles: ["panoramic_front", "rear"]),
        model("Vantrue", "Element 3", aliases: ["E3"], channels: 3, roles: ["front", "interior", "rear"]),
        model("Vantrue", "Element 2", aliases: ["E2"], channels: 2, roles: ["front", "rear"]),
        model("Vantrue", "Element 1 Pro", aliases: ["E1 Pro", "E1PRO"], channels: 1, roles: ["front"]),
        model("Vantrue", "Element 1", aliases: ["E1"], channels: 1, roles: ["front"]),
        model("Vantrue", "E1 Lite", channels: 1, roles: ["front"]),
        model("Vantrue", "E2 Pro", aliases: ["E2PRO"], notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "S1 Pro", channels: 2, roles: ["front", "rear"]),
        model("Vantrue", "S1 Pro Max", aliases: ["S1PROMAX"], notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "S1", channels: 2, roles: ["front", "rear"]),
        model("Vantrue", "S2", channels: 2, roles: ["front", "rear"]),
        model("Vantrue", "Falcon 1", aliases: ["F1"], channels: 2, roles: ["front", "rear"]),
        model("Vantrue", "P2", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "N1 Pro", aliases: ["N1PRO"], notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "N2", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "X4S", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "X4", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "T3", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "T2", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "M3", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "M2", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "VP05", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "VP03", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),
        model("Vantrue", "VP01", notes: "Official manual-listed model; card layout and channel configuration still need a submitted scan."),

        // 70mai
        model("70mai", "T800", channels: 3, roles: ["front", "rear", "interior"]),
        model("70mai", "4K Omni X800", aliases: ["70MAI_X800", "X800", "4K Omni", "4K Omni X800", "Dash Cam 4K Omni X800"], channels: 2, roles: ["front", "rear"]),
        model("70mai", "X200", aliases: ["Dash Cam Omni"], channels: 1, roles: ["rotating_front"]),
        model("70mai", "A810S", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A810", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A810 Lite", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A800", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A800SE", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A800S", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A510", channels: 2, roles: ["front", "rear"]),
        model("70mai", "Pro Plus+", aliases: ["A500S"], channels: 2, roles: ["front", "rear"]),
        model("70mai", "A410", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A400", channels: 2, roles: ["front", "rear"]),
        model("70mai", "A200", channels: 2, roles: ["front", "rear"]),
        model("70mai", "M310 Plus 4K", channels: 1, roles: ["front"]),
        model("70mai", "M310", channels: 1, roles: ["front"]),
        model("70mai", "M500", channels: 1, roles: ["front"]),
        model("70mai", "M300", channels: 1, roles: ["front"]),
        model("70mai", "T400", channels: 2, roles: ["front", "rear"]),

        // Tesla
        model("Tesla", "TeslaCam 6-Camera", aliases: ["TeslaCam HW4", "TeslaCam Pillar Cameras", "Tesla Dashcam 6-Camera"], channels: 6, roles: ["front", "rear", "left_repeater", "right_repeater", "left_pillar", "right_pillar"], parkingModes: ["RecentClips rolling buffer", "SavedClips manually saved dashcam events", "SentryClips sentry/parking events"], notes: "TeslaCam USB layout with front, back/rear, left/right repeater, and left/right pillar camera files. Exact Tesla vehicle generation still needs metadata or user/card submission context."),
        model("Tesla", "TeslaCam 4-Camera", aliases: ["TeslaCam Legacy", "Tesla Dashcam 4-Camera"], channels: 4, roles: ["front", "rear", "left_repeater", "right_repeater"], parkingModes: ["RecentClips rolling buffer", "SavedClips manually saved dashcam events", "SentryClips sentry/parking events"], notes: "TeslaCam USB layout with front, back/rear, and left/right repeater camera files. Older tooling used rear_view on some exports; newer files commonly use back."),
        model("Tesla", "TeslaCam", aliases: ["Tesla Dashcam"], channels: nil, roles: ["front", "rear", "left_repeater", "right_repeater", "left_pillar", "right_pillar"], parkingModes: ["RecentClips", "SavedClips", "SentryClips"], notes: "Generic TeslaCam family entry. Do not exact-ID from volume label alone; use TeslaCam folder shape, observed channels, SEI/model metadata when available, or trained evidence."),

        // Other manufacturers already researched for selector/profile candidates.
        model("Redtiger", "F77", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "4K"], sensors: ["front": "Sony IMX678", "rear": "Sony IMX678"], sensorNotes: ["eMMC", "Long Parking Mode Wakeup Times"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official current 2CH product, 4K+4K dual IMX678, voice control, 5.8 GHz Wi-Fi. Sensor notes imported from first-party research."),
        model("Redtiger", "F7NP", aliases: ["F7N Plus", "F7NP Plus"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2.5K"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official current 2CH front/rear 4K dash cam family. Resolution note imported from first-party research."),
        model("Redtiger", "F7NA", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official current/new 2CH Sony STARVIS 2 front/rear model."),
        model("Redtiger", "F7NT", aliases: ["F7N Touch"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "1080p"], sensors: ["front": "Sony STARVIS 2"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official current 2CH touch-screen 4K dual dash cam. Sensor note imported from first-party research."),
        model("Redtiger", "F7N Elite", aliases: ["F7NElite"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "1080p"], sensors: ["front": "Sony STARVIS 2"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "First-party research lists this as a 4K/1080p STARVIS 2 front-sensor model."),
        model("Redtiger", "VC70", aliases: ["ViewClear 70"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2.5K"], sensors: ["front": "Sony IMX678", "rear": "OmniVision OS04J10"], parkingModes: ["Super Night Vision parking mode", "24/7 parking protection", "hardwire parking monitor"], notes: "Official current 2CH 4K dual HDR/Super Night Vision model. Sensor notes imported from first-party research."),
        model("Redtiger", "F17 Elite", aliases: ["F17Elite"], channels: 3, roles: ["front", "interior", "rear"], resolutions: ["front": "4K", "rear": "2.5K", "interior": "1080p"], sensors: ["front": "Sony IMX678", "rear": "Sony IMX675", "interior": "Sony IMX307 STARVIS"], parkingModes: ["NiteGuard parking mode", "24/7 parking protection", "hardwire parking monitor"], notes: "Official current 3CH 4K full-night-color Wi-Fi 6 model. Sensor notes imported from first-party research."),
        model("Redtiger", "F17", channels: 3, roles: ["front", "interior", "rear"], resolutions: ["front": "4K", "interior": "1080p", "rear": "1080p"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official 3CH 4K / 5 GHz Wi-Fi model."),
        model("Redtiger", "A6", channels: 3, roles: ["front", "interior", "rear"], resolutions: ["front": "4K"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official current 3CH model."),
        model("Redtiger", "VP20", channels: 3, roles: ["front", "interior", "rear"], notes: "Official current 3CH IR night-view model."),
        model("Redtiger", "F17 Plus", channels: 4, roles: ["front", "rear", "left", "right"], resolutions: ["front": "4K", "rear": "1080p", "left": "1080p", "right": "1080p"], sensors: ["front": "Sony IMX675"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Official current 4CH STARVIS 2 touch-screen model. First-party research tracks this as 4K / 1080p / 1080p / 1080p with IMX675 front."),
        model("Redtiger", "VP40", aliases: ["VisionPano 40"], channels: 4, roles: ["front", "rear", "left", "right"], resolutions: ["front": "2.5K", "rear": "2.5K", "left": "1080p", "right": "1080p"], parkingModes: ["parking monitor", "24/7 parking protection", "hardwire parking monitor"], notes: "Official current 4CH VisionPano model with dual STARVIS 2 HDR."),
        model("Redtiger", "F7N", aliases: ["F7NS"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Legacy/current F7N family; firmware archives are model-coded but internal files are generic/chipset-style."),
        model("Redtiger", "F9", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "1080p"], sensors: ["front": "Sony STARVIS 2"], parkingModes: ["24/7 parking protection", "hardwire parking monitor"], notes: "Mirror dashcam family. Sensor note imported from first-party research."),
        model("Redtiger", "F8", channels: 1, roles: ["front"], resolutions: ["front": "4K"], notes: "Firmware archive observed in official Redtiger firmware research; internal firmware filename is chipset-style."),
        model("Redtiger", "F5", channels: 1, roles: ["front"]),
        model("Redtiger", "F4", channels: 1, roles: ["front"]),
        model("Redtiger", "F4 Pro", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "1080p"], notes: "First-party research lists this as a 4K/1080p model."),
        model("Redtiger", "F9 Lite", channels: 1, roles: ["front"], resolutions: ["front": "4K"], notes: "First-party research lists this as a 4K model."),
        model("Redtiger", "T700 RVM", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "1080p"], notes: "First-party research lists this as a 4K/1080p rear-view-mirror model."),
        model("Redtiger", "VS10 4G LTE", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2K", "rear": "1080p"], notes: "First-party research lists this as a 2K/1080p 4G LTE model."),
        model("Redtiger", "F3", channels: 1, roles: ["front"]),
        model("Rove", "R2-4K Dual Pro", channels: 2, roles: ["front", "rear"]),
        model("Rove", "R2-4K Dual", channels: 2, roles: ["front", "rear"]),
        model("Rove", "R2-4K Pro", channels: 1, roles: ["front"]),
        model("Rove", "R3", channels: 3, roles: ["front", "interior", "rear"]),
        model("GoPro", "MISSION 1", aliases: ["Mission 1"], channels: 1, roles: ["primary"], resolutions: ["primary": "8K30, 4K120, 1080p240, 1440p240"], sensors: ["primary": "1-inch"], parkingModes: ["looping", "time lapse", "night lapse", "endurance"], notes: "Current compact cinematic camera candidate from GoPro compare. GP3, 1-inch sensor, H.265 MP4, 240 Mbps max bitrate, 50MP/12MP photo modes, 8K30 and 4K120 video. Exact model should come from version.txt when present."),
        model("GoPro", "MISSION 1 PRO", aliases: ["Mission 1 Pro"], channels: 1, roles: ["primary"], resolutions: ["primary": "8K60, 8K Open Gate 30, 4K240, 1080p480, 1440p480"], sensors: ["primary": "1-inch"], parkingModes: ["looping", "time lapse", "night lapse", "endurance"], notes: "Current pro compact cinematic camera candidate from GoPro compare. GP3, 1-inch sensor, H.265 MP4, 240 Mbps max bitrate, Burst Slo-Mo up to 1080p960 for 10s, 50MP/12MP photo modes. Exact model should come from version.txt when present."),
        model("GoPro", "MISSION 1 PRO ILS", aliases: ["Mission 1 Pro ILS", "MISSION 1 ILS", "Mission 1 ILS"], channels: 1, roles: ["primary"], resolutions: ["primary": "8K60, 8K Open Gate 30, 4K240, 1080p480, 1440p480"], sensors: ["primary": "1-inch"], parkingModes: ["looping", "time lapse", "night lapse", "endurance"], notes: "Coming-soon MISSION 1 PRO interchangeable-lens-system candidate for Micro Four Thirds lenses. Use the shared MISSION media handling, but treat final card behavior as provisional until sampled."),
        model("GoPro", "MISSION 1 PRO Grip Edition", aliases: ["Mission 1 Pro Grip Edition"], channels: 1, roles: ["primary"], resolutions: ["primary": "8K60, 8K Open Gate 30, 4K240"], sensors: ["primary": "1-inch"], parkingModes: ["looping", "time lapse", "night lapse", "endurance"], notes: "MISSION 1 PRO bundle/edition candidate from the product page. Internal matching should collapse card behavior to MISSION 1 PRO if version.txt only reports the base camera."),
        model("GoPro", "MISSION 1 PRO Creator Edition", aliases: ["Mission 1 Pro Creator Edition"], channels: 1, roles: ["primary"], resolutions: ["primary": "8K60, 8K Open Gate 30, 4K240"], sensors: ["primary": "1-inch"], parkingModes: ["looping", "time lapse", "night lapse", "endurance"], notes: "Coming-soon MISSION 1 PRO creator bundle candidate. Accessory bundle, not necessarily a distinct card signature."),
        model("GoPro", "MISSION 1 PRO Ultimate Creator Edition", aliases: ["Mission 1 Pro Ultimate Creator Edition"], channels: 1, roles: ["primary"], resolutions: ["primary": "8K60, 8K Open Gate 30, 4K240"], sensors: ["primary": "1-inch"], parkingModes: ["looping", "time lapse", "night lapse", "endurance"], notes: "Coming-soon MISSION 1 PRO bundle candidate with gimbal/audio/lighting accessories. Accessory bundle, not necessarily a distinct card signature."),
        model("GoPro", "HERO13 Black", aliases: ["Hero 13 Black", "HERO 13 Black", "HERO13"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240, 1080p240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Current action camera candidate from GoPro compare. Version.txt camera type should be exact model evidence."),
        model("GoPro", "HERO13 Black Creator Edition", aliases: ["Hero 13 Black Creator Edition", "HERO 13 Black Creator Edition", "HERO13 Creator Edition"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240, 1080p240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Current HERO13 Black bundle/edition from GoPro compare. Accessory edition, so card evidence may report HERO13 Black rather than this full bundle name."),
        model("GoPro", "HERO13 Black Ultra Wide Edition", aliases: ["Hero 13 Black Ultra Wide Edition", "HERO 13 Black Ultra Wide Edition", "HERO13 Ultra Wide Edition"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240, 1080p240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Current HERO13 Black edition from GoPro compare. Likely accessory/lens-kit variant; treat as candidate hint unless version.txt explicitly names it."),
        model("GoPro", "HERO12 Black", aliases: ["Hero 12 Black", "HERO 12 Black", "HERO12"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Current compare-page action camera candidate. Uses GoPro DCIM media structure and chaptered video files; version.txt camera type should be exact model evidence."),
        model("GoPro", "HERO11 Black", aliases: ["Hero 11 Black", "HERO 11 Black", "HERO11"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Action camera candidate. Later HERO chapter size differs from HERO9/10/8 family per GoPro support; version.txt camera type should be exact model evidence."),
        model("GoPro", "HERO11 Black Mini", aliases: ["Hero 11 Black Mini", "HERO 11 Black Mini", "HERO11 Mini"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Screenless HERO11-family action camera candidate."),
        model("GoPro", "HERO10 Black", aliases: ["Hero 10 Black", "HERO 10 Black", "HERO10"], channels: 1, roles: ["primary"], resolutions: ["primary": "5.3K60, 4K120, 2.7K240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Action camera candidate sharing the HERO9/8/7/6/5 Black chapter-size family."),
        model("GoPro", "HERO9 Black", aliases: ["Hero 9 Black", "HERO 9 Black"], channels: 1, roles: ["primary"], resolutions: ["primary": "5K30, 4K60, 4K30 looping common"], parkingModes: ["looping 5/20/60/120 minutes/max"], notes: "First-party use includes 5K continuous video and 4K30 5-minute looping. GoPro support says HERO9 uses approx. 4GB chapters; 5-minute looping creates one-minute chapters."),
        model("GoPro", "HERO8 Black", aliases: ["Hero 8 Black", "HERO 8 Black", "HERO8"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K60, 2.7K120, 1080p240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Action camera candidate sharing the HERO9/10 chaptering family."),
        model("GoPro", "HERO7 Black", aliases: ["Hero 7 Black", "HERO 7 Black", "HERO7"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K60, 2.7K120, 1080p240"], parkingModes: ["looping", "time lapse", "TimeWarp"], notes: "Older HERO Black candidate. Exact model should come from version.txt when present."),
        model("GoPro", "HERO6 Black", aliases: ["Hero 6 Black", "HERO 6 Black", "HERO6"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K60, 2.7K120, 1080p240"], parkingModes: ["looping", "time lapse"], notes: "Older HERO Black candidate. Exact model should come from version.txt when present."),
        model("GoPro", "HERO5 Black", aliases: ["Hero 5 Black", "HERO 5 Black", "HERO5"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K30, 2.7K60, 1080p120"], parkingModes: ["looping", "time lapse"], notes: "Older HERO Black candidate. Exact model should come from version.txt when present."),
        model("GoPro", "HERO4 Black", aliases: ["Hero 4 Black", "HERO 4 Black", "HERO4 Black"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K30, 2.7K60, 1080p120"], parkingModes: ["looping", "time lapse"], notes: "Legacy HERO candidate; media layout may be older than modern HERO Black cards."),
        model("GoPro", "HERO4 Silver", aliases: ["Hero 4 Silver", "HERO 4 Silver", "HERO4 Silver"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K15, 2.7K30, 1080p60"], parkingModes: ["looping", "time lapse"], notes: "Legacy HERO candidate; media layout may be older than modern HERO Black cards."),
        model("GoPro", "LIT HERO", aliases: ["Lit Hero", "LIT HERO 4K"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K60, 4:3 video, photo"], parkingModes: [], notes: "Current compact 4K camera from GoPro compare/nav. Built-in LED light and simplified modes: Video, 4:3 Video, Slo-Mo, Photo. Exact model should come from version.txt when present."),
        model("GoPro", "HERO", aliases: ["Hero 2024", "HERO 2024"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K30, 2.7K60, 1080p60"], parkingModes: ["time lapse"], notes: "Compact HERO candidate. GoPro product page lists 4K30 and 2.7K60/1080p60 slo-mo."),
        model("GoPro", "MAX2", aliases: ["MAX 2", "Max2"], channels: 1, roles: ["360_primary"], resolutions: ["360_primary": "8K 360, 5.6K60 360, 4K100 360, 4K60 single-lens"], parkingModes: ["time lapse"], notes: "Current 360 action camera candidate from GoPro compare/nav. Product page lists True 8K 360, 4K100 spherical slow motion, replaceable lenses, and up to 300 Mbps via GoPro Labs."),
        model("GoPro", "MAX", channels: 1, roles: ["360_primary"], resolutions: ["360_primary": "5.6K 360, 1440p60/1080p60 HERO mode"], parkingModes: ["time lapse"], notes: "360 action camera candidate. File structure may differ from HERO Black cards."),
        model("GoPro", "Fusion", channels: 1, roles: ["360_primary"], resolutions: ["360_primary": "5.2K30 360"], parkingModes: ["time lapse"], notes: "Legacy 360 action camera candidate. Card structure can differ from HERO Black cards."),
        model("Wolfbox", "G900 Pro", aliases: ["G900Pro", "G900Pro 12MP", "G900 PRO"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2.5K"], sensors: ["front": "Sony STARVIS 2 IMX678", "rear": "Sony STARVIS IMX335"], parkingModes: ["parking monitoring with hardwire kit", "instant impact detection", "loop recording", "adjustable reversing assist"], notes: "Official G900Pro pages list a 12-inch mirror, 12MP/8MP-class IMX678 front camera, rear camera, Wi-Fi, GPS, voice control, and parking monitoring."),
        model("Wolfbox", "G900", channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K"], parkingModes: ["parking monitoring", "G-sensor alerts", "reverse parking guide lines"], notes: "G900 family mirror dashcam with front/rear camera support."),
        model("Wolfbox", "G900 TriPro", aliases: ["G900 Tripro", "G900TriPro"], channels: 3, roles: ["front", "rear", "interior"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "Official FAQ says 3CH mode uses Front / Rear / Cabin ports; third camera can be cabin or bumper."),
        model("Wolfbox", "G900 TriPro Bumper", aliases: ["G900 Tripro Bumper"], channels: 3, roles: ["front", "rear", "bumper"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "Official product nav has a bumper-version 3CH G900 TriPro."),
        model("Wolfbox", "G900 TriPro Cabin", aliases: ["G900 Tripro Cabin"], channels: 3, roles: ["front", "rear", "interior"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "Official product nav has a cabin-version 3CH G900 TriPro."),
        model("Wolfbox", "G850 Pro", aliases: ["G850Pro"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2K"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "Official comparison lists 4K front and 2K rear mirror dash cam with Wi-Fi/app, voice control, and ADAS."),
        model("Wolfbox", "G850", channels: 2, roles: ["front", "rear"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "G850/G850 Pro family; FAQ mentions external GPS module and anti-flicker settings."),
        model("Wolfbox", "G840S", channels: 2, roles: ["front", "rear"], parkingModes: ["parking monitoring", "reverse parking guide lines"], notes: "Mirror family. FAQ references G840S/G840H rear camera via Rear IN port."),
        model("Wolfbox", "G840H", channels: 2, roles: ["front", "rear"], resolutions: ["front": "2.5K", "rear": "1080p"], parkingModes: ["parking monitoring", "parking assistance", "reverse parking guide lines"], notes: "Official comparison lists 2.5K front and 1080p rear, Wi-Fi/app, 12-inch mirror display."),
        model("Wolfbox", "G840H Mini", channels: 2, roles: ["front", "rear"]),
        model("Wolfbox", "G930", channels: 2, roles: ["front", "rear"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "FAQ groups G890/G910/G930 series with rear camera and parking monitor behavior."),
        model("Wolfbox", "G910", channels: 2, roles: ["front", "rear"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "FAQ groups G890/G910/G930 series."),
        model("Wolfbox", "G890", channels: 2, roles: ["front", "rear"], parkingModes: ["parking monitoring", "G-sensor alerts"], notes: "FAQ groups G890/G910/G930 series."),
        model("Wolfbox", "G880", channels: 2, roles: ["front", "rear"]),
        model("Wolfbox", "T10", channels: 2, roles: ["front", "rear"]),
        model("Wolfbox", "X5", channels: 2, roles: ["front", "rear"]),
        model("Wolfbox", "i07", channels: 2, roles: ["front", "rear"]),
        model("Wolfbox", "G700", channels: 2, roles: ["front", "rear"]),
        model("Cansonic", "UltraDash Z4 Standard", aliases: ["UD_Z4"], channels: 3, roles: ["front", "telephoto", "rear"]),
        model("Cansonic", "UltraDash Z4 Commercial", aliases: ["UD_Z4C"], channels: 3, roles: ["front", "telephoto", "rear"]),
        model("Cansonic", "UltraDash Z3+ Standard", aliases: ["UD_Z3+"], channels: 3, roles: ["wide", "telephoto", "rear"]),
        model("Cansonic", "UltraDash Z3+ Commercial", aliases: ["UD_Z3+C"], channels: 3, roles: ["wide", "telephoto", "rear"]),
        model("FineVu", "GX4K", channels: 2, roles: ["front", "rear"]),
        model("FineVu", "GX1000", channels: 2, roles: ["front", "rear"]),
        model("Nextbase", "Piqo", channels: 1, roles: ["front"]),
        model("Nextbase", "iQ", channels: 3, roles: ["front", "interior", "rear"]),
        model("Nextbase", "622GW", channels: 2, roles: ["front", "rear"]),
        model("Garmin", "Dash Cam X310", channels: 1, roles: ["front"]),
        model("Garmin", "Dash Cam Mini 3", channels: 1, roles: ["front"]),
        model("Momento", "M8 Max", channels: 2, roles: ["front", "rear"]),
        model("Momento", "M7", channels: 3, roles: ["front", "rear", "interior"]),
        model("Rexing", "V55", channels: 3, roles: ["front", "rear", "interior"]),
        model("Rexing", "R4", channels: 4, roles: ["front", "rear", "left", "right"]),
        model("Escort", "MAXcam 360c", channels: 1, roles: ["front"]),
        model("Escort", "M2", channels: 1, roles: ["front"]),
        model("Escort", "M1", channels: 1, roles: ["front"]),
        model("Sony", "A7 III", aliases: ["ILCE-7M3", "Alpha A7 III", "A73"], channels: 1, roles: ["primary"], resolutions: ["primary": "4K30 / 1080p"], notes: "Mirrorless camera; ARW stills and XAVC S video."),
        model("Cobra", "SC 400D", channels: 3, roles: ["front", "rear", "interior"]),
        model("Cobra", "SC 250R", channels: 2, roles: ["front", "rear"]),
        model("Cobra", "Road Scout", channels: 1, roles: ["front"]),
        model("Nexar", "Beam2 Pro", channels: 2, roles: ["front", "interior"]),
        model("Nexar", "Beam2", channels: 2, roles: ["front", "interior"]),
        model("Pelsee", "P12 Pro Max", channels: 2, roles: ["front", "rear"]),
        model("Pelsee", "P1 Duo", channels: 2, roles: ["front", "rear"]),
        model("Miofive", "S1 Ultra", aliases: ["S1-Ultra", "S1 Ultra Dual", "S1 Ultra Dual 4K", "S1-Ultra(Front 4K+Rear 4K)"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K30", "rear": "4K"], parkingModes: ["24-hour parking monitor", "HWK2 required"], notes: "Official current S1-series flagship, dual 4K front/rear, 3-inch IPS, 5 GHz Wi-Fi, Bluetooth 4.2, GPS, Type-C, supercapacitor."),
        model("Miofive", "S1 Pro", aliases: ["S1-Pro", "S1 Pro 4K+2K", "S1-Pro(Front 4K+Rear 2K)"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K30", "rear": "2K30"], parkingModes: ["24-hour parking monitor", "HWK2 required"], notes: "Official compare page lists 4K front and 2K rear, dual channel, 3-inch IPS, GPS, supercapacitor."),
        model("Miofive", "S1 E", aliases: ["S1E", "S1 E 4K", "S1 E(Front 4K)"], channels: 1, roles: ["front"], resolutions: ["front": "4K25"], parkingModes: ["24-hour parking monitor", "HWK2 required"], notes: "Official compare page lists single-channel front 4K, Wi-Fi 6, Bluetooth 4.2, GPS, supercapacitor, no included card."),
        model("Miofive", "S1", aliases: ["S1+32G", "S1 4K", "S1+32G(Front 4K)"], channels: 1, roles: ["front"], resolutions: ["front": "4K30"], parkingModes: ["24-hour parking monitor", "HWK2 required"], notes: "Official compare page lists single-channel 4K, included 32 GB card, 3-inch IPS, GPS, supercapacitor."),
        model("Miofive", "MF02", aliases: ["Miofive 4K+2K Dual", "MF02(Front 4K+Rear 2K)"], channels: 2, roles: ["front", "rear"], resolutions: ["front": "4K", "rear": "2K"], parkingModes: ["24-hour parking monitor", "HWK1 required"], notes: "Official product page lists 4K+2K dual dash cam, 5 GHz Wi-Fi, GPS, built-in 128 GB eMMC, Micro USB, lithium backup battery."),
        model("Miofive", "Mini 2", aliases: ["Mini2"], channels: 1, roles: ["front"], notes: "Listed in the official compare page; specs need additional page/manual evidence before profile training."),
        model("iiwey", "N9", channels: 5, roles: ["front", "rear", "left", "right", "interior"]),
        model("iiwey", "N5 Pro", channels: 4, roles: ["front", "rear", "left", "right"]),
        model("Coolcrazy", "N8 Pro", channels: 2, roles: ["front", "rear"]),
        model("Pruveeo", "D90-4CH-RGW", channels: 4, roles: ["front", "rear", "left", "right"]),
        model("Pruveeo", "RD316", channels: 2, roles: ["front", "rear"]),
        model("Terunsoul", "D016 4K+4K", channels: 2, roles: ["front", "rear"]),
        model("Terunsoul", "4K 3-Channel", channels: 3, roles: ["front", "interior", "rear"]),
        model("Botslab", "G980H", channels: 4, roles: ["front", "rear", "left", "right"])
    ]

    static func exactVolumeLabelMatch(_ label: String) -> KnownDashcamModel? {
        let normalized = compact(label)
        guard isSpecificVolumeLabel(label) else { return nil }

        let matches = models.filter { model in
            model.searchNames.contains { compact($0) == normalized }
        }
        return matches.count == 1 ? matches[0] : nil
    }

    static func exactModelMatch(manufacturer: String, modelText: String) -> KnownDashcamModel? {
        let normalizedManufacturer = compact(manufacturer)
        let normalizedModel = compact(modelText)
        guard !normalizedManufacturer.isEmpty, !normalizedModel.isEmpty else { return nil }

        return models.first { model in
            compact(model.manufacturer) == normalizedManufacturer &&
                model.searchNames.contains { compact($0) == normalizedModel }
        }
    }

    static func exactBlackVueModelMention(_ modelText: String) -> KnownDashcamModel? {
        let normalizedModelText = compact(modelText)
        guard !normalizedModelText.isEmpty else { return nil }

        return exactModelMention(modelText, manufacturer: "BlackVue")
    }

    static func exactModelMention(_ modelText: String, manufacturer: String? = nil) -> KnownDashcamModel? {
        let normalizedModelText = compact(modelText)
        let normalizedManufacturer = manufacturer.map(compact)
        guard !normalizedModelText.isEmpty else { return nil }

        var bestMatch: (model: KnownDashcamModel, length: Int)?
        for model in models {
            if let normalizedManufacturer,
               compact(model.manufacturer) != normalizedManufacturer {
                continue
            }

            for searchName in model.searchNames {
                let normalizedSearchName = compact(searchName)
                guard !normalizedSearchName.isEmpty,
                      normalizedModelText.contains(normalizedSearchName) else {
                    continue
                }
                if bestMatch == nil || normalizedSearchName.count > bestMatch!.length {
                    bestMatch = (model, normalizedSearchName.count)
                }
            }
        }
        return bestMatch?.model
    }

    static func isSpecificVolumeLabel(_ label: String) -> Bool {
        let normalized = compact(label)
        guard !normalized.isEmpty else { return false }
        return !genericVolumeLabels.contains(normalized)
    }

    private static func model(
        _ manufacturer: String,
        _ model: String,
        aliases: [String] = [],
        channels: Int? = nil,
        roles: [String] = [],
        resolutions: [String: String] = [:],
        sensors: [String: String] = [:],
        sensorNotes: [String] = [],
        parkingModes: [String] = [],
        notes: String = ""
    ) -> KnownDashcamModel {
        KnownDashcamModel(
            manufacturer: manufacturer,
            model: model,
            aliases: aliases,
            channels: channels,
            channelRoles: roles,
            channelResolutions: resolutions,
            channelSensors: sensors,
            sensorNotes: sensorNotes,
            parkingModes: parkingModes,
            notes: notes
        )
    }

    private static func compact(_ value: String) -> String {
        value
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

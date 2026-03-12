import SwiftUI
import MapKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Models
// ─────────────────────────────────────────────────────────────────────────────

enum MarkerCategory: String, CaseIterable, Identifiable {
    case accommodation, cycling, nature
    var id: String { rawValue }

    var label: String {
        switch self {
        case .accommodation: return "Stay"
        case .cycling:       return "Cycling"
        case .nature:        return "Nature"
        }
    }
    var sfSymbol: String {
        switch self {
        case .accommodation: return "bed.double.fill"
        case .cycling:       return "bicycle"
        case .nature:        return "leaf.fill"
        }
    }
    var uiColor: UIColor {
        switch self {
        case .accommodation: return UIColor(red: 0.05, green: 0.42, blue: 0.82, alpha: 1)
        case .cycling:       return UIColor(red: 0.10, green: 0.55, blue: 0.15, alpha: 1)
        case .nature:        return UIColor(red: 0.65, green: 0.40, blue: 0.05, alpha: 1)
        }
    }
    var color: Color {
        switch self {
        case .accommodation: return Color(red: 0.05, green: 0.42, blue: 0.82)
        case .cycling:       return Color(red: 0.10, green: 0.55, blue: 0.15)
        case .nature:        return Color(red: 0.65, green: 0.40, blue: 0.05)
        }
    }

    var overpassFilters: [String] {
        switch self {
        case .accommodation:
            return [
                "[\"tourism\"~\"hotel|hostel|guest_house|motel|camp_site|alpine_hut|chalet|wilderness_hut|caravan_site|apartment|resort\"]"
            ]
        case .cycling:
            return [
                "[\"amenity\"=\"bicycle_rental\"]",
                "[\"amenity\"=\"bicycle_repair_station\"]",
                "[\"shop\"=\"bicycle\"]",
            ]
        case .nature:
            return [
                "[\"leisure\"~\"nature_reserve|park|garden\"]",
                "[\"boundary\"=\"national_park\"]",
                "[\"natural\"~\"wood|forest|beach|cliff|peak|waterfall|spring|wetland\"]",
                "[\"tourism\"~\"viewpoint|picnic_site|wilderness_hut\"]",
            ]
        }
    }
}

struct EcoMarker: Identifiable {
    let id        = UUID()
    let name:     String
    let lat:      Double
    let lon:      Double
    let category: MarkerCategory
    var website:  String?
    var phone:    String?
    var address:  String?
    var openingHours: String?
    var description: String?
    var stars:    String?
    var placesURL: String?

    var coord: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }

    var appleMapsURL: URL? {
        let n = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "maps://?q=\(n)&ll=\(lat),\(lon)")
    }
    var googleMapsURL: URL? {
        let n = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(n)&center=\(lat),\(lon)")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Continent presets
// ─────────────────────────────────────────────────────────────────────────────

enum Continent: String, CaseIterable, Identifiable {
    case lebanon      = "Lebanon"
    case europe       = "Europe"
    case asia         = "Asia"
    case africa       = "Africa"
    case northAmerica = "N. America"
    case southAmerica = "S. America"
    case australia    = "Australia"
    case antarctica   = "Antarctica"
    var id: String { rawValue }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .lebanon:      return .init(latitude: 33.8547,  longitude: 35.8623)
        case .europe:       return .init(latitude: 50.0,     longitude: 10.0)
        case .asia:         return .init(latitude: 35.0,     longitude: 100.0)
        case .africa:       return .init(latitude: 5.0,      longitude: 20.0)
        case .northAmerica: return .init(latitude: 45.0,     longitude: -100.0)
        case .southAmerica: return .init(latitude: -15.0,    longitude: -60.0)
        case .australia:    return .init(latitude: -25.0,    longitude: 133.0)
        case .antarctica:   return .init(latitude: -80.0,    longitude: 0.0)
        }
    }
    var radiusKm: Double {
        switch self {
        case .lebanon: return 80
        case .antarctica: return 1500
        default: return 2500
        }
    }
    var altitude: CLLocationDistance {
        switch self {
        case .lebanon: return 400_000
        case .antarctica: return 8_000_000
        default: return 6_000_000
        }
    }
    var flag: String {
        switch self {
        case .lebanon:      return "🇱🇧"
        case .europe:       return "🌍"
        case .asia:         return "🌏"
        case .africa:       return "🌍"
        case .northAmerica: return "🌎"
        case .southAmerica: return "🌎"
        case .australia:    return "🌏"
        case .antarctica:   return "🧊"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Places Scraper
// Enriches markers with Nominatim reverse + builds Google Maps search URL
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class PlacesScraper {
    static let shared = PlacesScraper()
    private var cache: [String: ScrapedPlace] = [:]

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 10
        return URLSession(configuration: cfg)
    }()

    struct ScrapedPlace {
        var website: String?
        var phone: String?
        var googleMapsURL: String?
        var cachedAt: Date = Date()
    }

    func enrich(name: String, lat: Double, lon: Double) async -> ScrapedPlace {
        let key = "\(name)|\(String(format: "%.4f", lat))|\(String(format: "%.4f", lon))"

        // ✅ Check cache inside the function
        if let cached = cache[key], Date().timeIntervalSince(cached.cachedAt) < 3600 {
            return cached
        }

        var result = ScrapedPlace()
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        result.googleMapsURL = "https://www.google.com/maps/search/?api=1&query=\(enc)&center=\(lat),\(lon)"

        // Nominatim reverse for extratags (website, phone)
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/reverse")!
        comps.queryItems = [
            URLQueryItem(name: "lat",           value: String(lat)),
            URLQueryItem(name: "lon",           value: String(lon)),
            URLQueryItem(name: "format",        value: "jsonv2"),
            URLQueryItem(name: "extratags",     value: "1"),
            URLQueryItem(name: "addressdetails",value: "1"),
        ]

        if let url = comps.url,
           let (data, _) = try? await session.data(for: {
               var r = URLRequest(url: url)
               r.setValue("GreenGo/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
               return r
           }()) {
            struct NReverse: Decodable { let extratags: [String: String]? }
            if let parsed = try? JSONDecoder().decode(NReverse.self, from: data) {
                let tags = parsed.extratags ?? [:]
                result.website = tags["website"] ?? tags["url"] ?? tags["contact:website"]
                result.phone   = tags["phone"] ?? tags["contact:phone"]
            }
        }

        // Save to cache
        cache[key] = result
        return result
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Overpass + Nominatim loader
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
final class EcoMapLoader: ObservableObject {
    @Published var markers:   [EcoMarker] = []
    @Published var isLoading: Bool        = false
    @Published var errorMsg:  String?     = nil

    private(set) var lastLat: Double = 33.8547
    private(set) var lastLon: Double = 35.8623
    private(set) var lastRad: Double = 80.0

    private var cache: [String: [EcoMarker]] = [:]

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 45
        cfg.timeoutIntervalForResource = 90
        return URLSession(configuration: cfg)
    }()
    private let userAgent = "GreenGo/1.0 (iOS)"

    func load(lat: Double, lon: Double, radiusKm: Double,
              categories: [MarkerCategory] = MarkerCategory.allCases) async {
        // Round to ~2km grid so slight pans hit cache; cap radius at 80km for speed
        let rlat = (lat * 50).rounded() / 50
        let rlon = (lon * 50).rounded() / 50
        let rad  = min(radiusKm, 80.0)
        let key  = String(format: "%.2f,%.2f,%d", rlat, rlon, Int(rad))
        if let cached = cache[key] {
            markers = filterBy(cached, categories); return
        }
        isLoading = true; errorMsg = nil
        do {
            let r = try await fetchOverpass(lat: rlat, lon: rlon, radiusKm: rad)
            cache[key] = r
            markers = filterBy(r, categories)
        } catch {
            // Ignore cancellation — happens normally when user pans during debounce
            if (error as? URLError)?.code == .cancelled { isLoading = false; return }
            if error is CancellationError            { isLoading = false; return }
            let msg = (error as? URLError).map { "Network error: \($0.localizedDescription)" }
                   ?? "Map data error: \(error.localizedDescription)"
            errorMsg = msg
        }
        isLoading = false
    }

    func search(query: String, categories: [MarkerCategory] = MarkerCategory.allCases) async -> CLLocationCoordinate2D? {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        isLoading = true; errorMsg = nil
        defer { isLoading = false }
        guard let coord = try? await geocode(query: query) else {
            errorMsg = "Location not found: \"\(query)\""
            return nil
        }
        do {
            let rlat = (coord.latitude * 50).rounded() / 50
            let rlon = (coord.longitude * 50).rounded() / 50
            let rad  = 10.0
            let key  = String(format: "%.2f,%.2f,%d", rlat, rlon, Int(rad))
            if let cached = cache[key] {
                markers = filterBy(cached, categories); return coord
            }
            let r = try await fetchOverpass(lat: rlat, lon: rlon, radiusKm: rad)
            cache[key] = r
            markers = filterBy(r, categories)
        } catch {
            errorMsg = "Map data error: \(error.localizedDescription)"
        }
        return coord
    }

    private func fetchOverpass(lat: Double, lon: Double, radiusKm: Double) async throws -> [EcoMarker] {
        let rad = radiusKm * 1000  // metres for Overpass around filter
        var parts = ["[out:json][timeout:25];("]
        for cat in MarkerCategory.allCases {
            for f in cat.overpassFilters {
                parts.append("  node\(f)(around:\(Int(rad)),\(lat),\(lon));")
                parts.append("  way\(f)(around:\(Int(rad)),\(lat),\(lon));")
                parts.append("  relation\(f)(around:\(Int(rad)),\(lat),\(lon));")
            }
        }
        parts += [");", "out 300 center tags;"]
        let query = parts.joined(separator: "\n")

        var comps = URLComponents()
        comps.queryItems = [URLQueryItem(name: "data", value: query)]
        let encoded = comps.percentEncodedQuery!

        // Official Overpass API instances (source: wiki.openstreetmap.org/wiki/Overpass_API)
        // 1. overpass-api.de       — main instance, Frankfurt, 2 servers 128GB RAM, global
        // 2. private.coffee        — formerly kumi.systems, 4 servers 256GB RAM, no rate limit, global
        // 3. mail.ru               — 2 servers 384GB RAM, no rate limit, global
        // 4. nchc.org.tw           — Taiwan, good for Asia-Pacific
        // 5. osm.ch                — Switzerland only data, last resort
        let mirrors = [
            "https://overpass-api.de/api/interpreter",
            "https://overpass.private.coffee/api/interpreter",
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
            "https://overpass.nchc.org.tw/api/interpreter",
            "https://overpass.osm.ch/api/interpreter",
        ]
        var lastErr: Error = URLError(.timedOut)
        for mirror in mirrors {
            guard !Task.isCancelled, let url = URL(string: mirror) else { break }
            var req = URLRequest(url: url, timeoutInterval: 20)
            req.httpMethod = "POST"
            req.httpBody   = encoded.data(using: .utf8)
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            do {
                let (data, resp) = try await session.data(for: req)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                    lastErr = URLError(.badServerResponse); continue
                }
                return try parseOverpass(data: data)
            } catch {
                lastErr = error
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
        throw lastErr
    }

    private func parseOverpass(data: Data) throws -> [EcoMarker] {
        struct OEl: Decodable {
            let type: String; let lat, lon: Double?
            let center: OC?; let tags: [String: String]?
            struct OC: Decodable { let lat, lon: Double }
        }
        struct OR: Decodable { let elements: [OEl] }

        let resp = try JSONDecoder().decode(OR.self, from: data)
        var seen = Set<String>(); var out = [EcoMarker]()

        for el in resp.elements {
            let lat: Double; let lon: Double
            if let a = el.lat, let b = el.lon { lat = a; lon = b }
            else if let c = el.center { lat = c.lat; lon = c.lon }
            else { continue }

            let tags = el.tags ?? [:]
            guard let name = tags["name"] ?? tags["name:en"] ?? tags["brand"],
                  !name.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let dk = "\(name)|\(String(format: "%.4f", lat))|\(String(format: "%.4f", lon))"
            guard !seen.contains(dk) else { continue }
            seen.insert(dk)

            var m = EcoMarker(name: name, lat: lat, lon: lon, category: classify(tags: tags))
            m.website      = tags["website"] ?? tags["url"] ?? tags["contact:website"]
            m.phone        = tags["phone"] ?? tags["contact:phone"]
            m.openingHours = tags["opening_hours"]
            m.description  = tags["description"]
            m.stars        = tags["stars"] ?? tags["accommodation:stars"]
            let addrParts  = [tags["addr:housenumber"], tags["addr:street"],
                              tags["addr:city"], tags["addr:country"]].compactMap { $0 }
            if !addrParts.isEmpty { m.address = addrParts.joined(separator: ", ") }
            out.append(m)
        }
        return out
    }

    private func classify(tags: [String: String]) -> MarkerCategory {
        let tourism = tags["tourism"] ?? ""; let amenity = tags["amenity"] ?? ""
        let shop    = tags["shop"]    ?? ""; let route   = tags["route"]   ?? ""
        if amenity == "bicycle_rental" || amenity == "bicycle_repair_station"
           || shop == "bicycle" || route == "bicycle" { return .cycling }
        let hotels = ["hotel","hostel","guest_house","motel","camp_site","alpine_hut",
                      "chalet","wilderness_hut","caravan_site","apartment","resort",
                      "bed_and_breakfast","lodge"]
        if hotels.contains(tourism) { return .accommodation }
        return .nature
    }

    private func geocode(query: String) async throws -> CLLocationCoordinate2D {
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [URLQueryItem(name: "q", value: query),
                            URLQueryItem(name: "format", value: "json"),
                            URLQueryItem(name: "limit",  value: "1")]
        guard let url = comps.url else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        let (data, _) = try await session.data(for: req)
        struct NR: Decodable { let lat, lon: String }
        guard let r = try? JSONDecoder().decode([NR].self, from: data),
              let f = r.first, let lat = Double(f.lat), let lon = Double(f.lon)
        else { throw URLError(.cannotParseResponse) }
        return .init(latitude: lat, longitude: lon)
    }

    private func filterBy(_ all: [EcoMarker], _ cats: [MarkerCategory]) -> [EcoMarker] {
        cats.isEmpty ? all : all.filter { cats.contains($0.category) }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Native MKMapView
// ─────────────────────────────────────────────────────────────────────────────

final class EcoAnnotation: MKPointAnnotation {
    let category: MarkerCategory; let markerID: UUID
    init(_ m: EcoMarker) {
        category = m.category; markerID = m.id
        super.init()
        coordinate = m.coord; title = m.name
    }
}

struct NativeMapView: UIViewRepresentable {
    let markers:  [EcoMarker]
    var filter:   MarkerCategory?
    @Binding var selected:    EcoMarker?
    @Binding var panTo:       CLLocationCoordinate2D?
    @Binding var panAltitude: CLLocationDistance
    // Called when user finishes panning/zooming so MapView can load data for new region
    var onRegionChanged: ((CLLocationCoordinate2D, Double) -> Void)? = nil

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true; map.showsCompass = true
        map.mapType = .standard
        map.cameraBoundary  = MKMapView.CameraBoundary(mapRect: .world)
        map.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 300, maxCenterCoordinateDistance: 18_000_000)
        let cam = MKMapCamera()
        cam.centerCoordinate = .init(latitude: 33.8547, longitude: 35.8623)
        cam.altitude = 400_000
        map.setCamera(cam, animated: false)
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: "eco")
        map.register(MKMarkerAnnotationView.self,
                     forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        updateCoordinator(context)
        let visible = filter == nil ? markers : markers.filter { $0.category == filter }
        let currentIDs = Set(map.annotations.compactMap { ($0 as? EcoAnnotation)?.markerID })
        let neededIDs  = Set(visible.map(\.id))

        // Remove only pins that are no longer needed
        let toRemove = map.annotations.compactMap { $0 as? EcoAnnotation }.filter { !neededIDs.contains($0.markerID) }
        map.removeAnnotations(toRemove)

        // Add only new pins
        let existingIDs = currentIDs
        let toAdd = visible.filter { !existingIDs.contains($0.id) }.map { EcoAnnotation($0) }
        map.addAnnotations(toAdd)
        if let coord = panTo {
            let cam = MKMapCamera(); cam.centerCoordinate = coord; cam.altitude = panAltitude
            map.setCamera(cam, animated: true)
            DispatchQueue.main.async { context.coordinator.panToBinding.wrappedValue = nil }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func updateCoordinator(_ context: Context) {
        context.coordinator.parent          = self
        context.coordinator.selectedBinding = $selected
        context.coordinator.panToBinding    = $panTo
        context.coordinator.onRegionChanged = onRegionChanged
        // Rebuild index every time markers array changes
        context.coordinator.markerIndex = Dictionary(uniqueKeysWithValues: markers.map { ($0.id, $0) })
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeMapView
        var selectedBinding: Binding<EcoMarker?>
        var panToBinding:    Binding<CLLocationCoordinate2D?>
        var onRegionChanged: ((CLLocationCoordinate2D, Double) -> Void)?
        // Keep a UUID→EcoMarker map so didSelect always finds the marker
        // even after parent.markers has been replaced with a new load.
        var markerIndex: [UUID: EcoMarker] = [:]
        init(_ p: NativeMapView) {
            parent          = p
            selectedBinding = p.$selected
            panToBinding    = p.$panTo
            onRegionChanged = p.onRegionChanged
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if annotation is MKClusterAnnotation {
                let v = mapView.dequeueReusableAnnotationView(
                    withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier,
                    for: annotation) as! MKMarkerAnnotationView
                v.markerTintColor = UIColor(red: 0.08, green: 0.50, blue: 0.15, alpha: 1)
                return v
            }
            guard let eco = annotation as? EcoAnnotation else { return nil }
            let v = mapView.dequeueReusableAnnotationView(withIdentifier: "eco",
                for: annotation) as! MKMarkerAnnotationView
            v.markerTintColor = eco.category.uiColor
            v.glyphImage      = UIImage(systemName: eco.category.sfSymbol)
            v.titleVisibility = .hidden; v.subtitleVisibility = .hidden
            v.clusteringIdentifier = eco.category.rawValue
            v.displayPriority = .defaultLow
            return v
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            guard let eco = annotation as? EcoAnnotation,
                  let mk  = markerIndex[eco.markerID]
            else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.selectedBinding.wrappedValue = mk
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            let mapRect = mapView.visibleMapRect
            let radiusMeters = max(mapRect.size.width, mapRect.size.height) / 2
            let radiusKm = max(10, min(120, radiusMeters / 1000))
            onRegionChanged?(region.center, radiusKm)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Map Info Overlay (iOS 26 glass panel, like AIA original)
// ─────────────────────────────────────────────────────────────────────────────

struct MapInfoOverlay: View {
    @EnvironmentObject private var appState: AppState
    @Binding var isShowing: Bool
    @State private var doNotShow = false
    @State private var slid      = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                Spacer()

                VStack(alignment: .leading, spacing: 0) {

                    // Drag handle
                    HStack {
                        Spacer()
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: 40, height: 5)
                        Spacer()
                    }
                    .padding(.top, 12)

                    // Icon + title
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(red:0.15,green:0.70,blue:0.25),
                                             Color(red:0.02,green:0.38,blue:0.10)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 54, height: 54)
                            Image(systemName: "map.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Eco Map")
                                .font(.custom("AlumniSans-Bold", size: 28))
                                .foregroundStyle(.white)
                            Text("Powered by OpenStreetMap")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 22)

                    // Legend
                    VStack(spacing: 9) {
                        legendRow("bed.double.fill",
                                  color: Color(red:0.05,green:0.42,blue:0.82),
                                  title: "Eco-friendly Accommodation",
                                  detail: "Hotels · Hostels · Campsites")
                        legendRow("bicycle",
                                  color: Color(red:0.10,green:0.55,blue:0.15),
                                  title: "Cycling",
                                  detail: "Bike rentals · Shops · Repair")
                        legendRow("leaf.fill",
                                  color: Color(red:0.65,green:0.40,blue:0.05),
                                  title: "Nature",
                                  detail: "Parks · Reserves · Beaches")
                    }
                    .padding(.horizontal, 18)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(height: 1)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)

                    // Info line
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.white.opacity(0.45))
                            .font(.system(size: 13))
                        Text("Tap any pin for details, directions & website. Tap ⓘ on the map any time to re-open this guide.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                    // Do not show toggle
                    HStack {
                        Toggle(isOn: $doNotShow) {
                            Text("Don't show again")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Color(red:0.25,green:0.85,blue:0.35)))
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)

                    // Open Map button
                    Button { dismiss() } label: {
                        HStack {
                            Spacer()
                            Label("Open Map", systemImage: "map.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.black)
                            Spacer()
                        }
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [Color(red:0.45,green:0.95,blue:0.55),
                                         Color(red:0.20,green:0.85,blue:0.35)],
                                startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 36)
                }
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(LinearGradient(
                                    colors: [Color(red:0.04,green:0.16,blue:0.07).opacity(0.93),
                                             Color(red:0.01,green:0.08,blue:0.03).opacity(0.97)],
                                    startPoint: .top, endPoint: .bottom)))
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.10), lineWidth: 1))
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 30)
                .offset(y: slid ? 0 : 380)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { slid = true }
        }
    }

    private func dismiss() {
        appState.setSkipMapInfo(doNotShow)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) { slid = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            isShowing = false
        }
    }

    @ViewBuilder
    private func legendRow(_ icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.22))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.50))
            }
            Spacer()
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.055))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.07), lineWidth: 1)))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Marker Detail Sheet (iOS 26 glass)
// ─────────────────────────────────────────────────────────────────────────────

struct MarkerDetailSheet: View {
    let marker: EcoMarker
    @Environment(\.dismiss) private var dismiss
    @State private var enriched: EcoMarker? = nil
    @State private var loading = true
    private var d: EcoMarker { enriched ?? marker }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(red:0.04,green:0.12,blue:0.06).opacity(0.96),
                             Color(red:0.01,green:0.07,blue:0.03).opacity(0.99)],
                    startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.28))
                    .frame(width: 38, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // Header
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [marker.category.color.opacity(0.35),
                                                 marker.category.color.opacity(0.12)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 58, height: 58)
                                    .overlay(Circle().stroke(marker.category.color.opacity(0.35), lineWidth: 1.5))
                                Image(systemName: marker.category.sfSymbol)
                                    .font(.system(size: 23, weight: .semibold))
                                    .foregroundStyle(marker.category.color)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(d.name)
                                    .font(.custom("AlumniSans-Bold", size: 21))
                                    .foregroundStyle(.white)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack(spacing: 6) {
                                    categoryBadge
                                    if let s = d.stars, !s.isEmpty { starBadge(s) }
                                }
                            }
                            Spacer()
                            Button { dismiss() } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.55))
                                    .frame(width: 30, height: 30)
                                    .background(Color.white.opacity(0.10), in: Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 18)

                        // Detail rows
                        if loading {
                            HStack(spacing: 8) {
                                ProgressView().tint(.white.opacity(0.4)).scaleEffect(0.75)
                                Text("Loading details…")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.35))
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                        } else {
                            VStack(spacing: 7) {
                                if let a = d.address, !a.isEmpty {
                                    row("mappin.circle.fill", .red, a)
                                }
                                if let p = d.phone, !p.isEmpty {
                                    row("phone.fill", Color(red:0.2,green:0.85,blue:0.3), p, tap: true) {
                                        if let u = URL(string: "tel:\(p.filter { $0 != " " })") {
                                            UIApplication.shared.open(u)
                                        }
                                    }
                                }
                                if let h = d.openingHours, !h.isEmpty {
                                    row("clock.fill", .orange, h)
                                }
                                if let desc = d.description, !desc.isEmpty {
                                    row("text.quote", .cyan, desc)
                                }
                                row("location.fill", Color(red:0.4,green:0.6,blue:1.0),
                                    String(format: "%.5f°N, %.5f°E", marker.lat, marker.lon))
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 14)
                        }

                        // Action buttons
                        VStack(spacing: 9) {
                            actionBtn("Open in Apple Maps", "map.fill",
                                      [Color(red:0.2,green:0.6,blue:1.0), Color(red:0.1,green:0.4,blue:0.9)]) {
                                if let u = d.appleMapsURL { UIApplication.shared.open(u) }
                            }
                            if let site = d.website ?? d.placesURL, let u = URL(string: site) {
                                actionBtn("Visit Website", "safari.fill",
                                          [Color(red:0.3,green:0.8,blue:0.5), Color(red:0.1,green:0.6,blue:0.3)]) {
                                    UIApplication.shared.open(u)
                                }
                            }
                            if let gm = d.googleMapsURL {
                                actionBtn("Search on Google Maps", "magnifyingglass",
                                          [Color(red:0.9,green:0.35,blue:0.2), Color(red:0.75,green:0.15,blue:0.05)]) {
                                    UIApplication.shared.open(gm)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 36)
                    }
                }
            }
        }
        .task {
            if marker.website == nil || marker.phone == nil {
                let s = await PlacesScraper.shared.enrich(name: marker.name, lat: marker.lat, lon: marker.lon)
                var u = marker
                if u.website == nil { u.website = s.website }
                if u.phone   == nil { u.phone   = s.phone   }
                u.placesURL = s.googleMapsURL
                enriched = u
            } else {
                var u = marker
                let enc = marker.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                u.placesURL = "https://www.google.com/maps/search/?api=1&query=\(enc)&center=\(marker.lat),\(marker.lon)"
                enriched = u
            }
            loading = false
        }
    }

    private var categoryBadge: some View {
        Text(marker.category.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(marker.category.color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(marker.category.color.opacity(0.15), in: Capsule())
            .overlay(Capsule().stroke(marker.category.color.opacity(0.30), lineWidth: 1))
    }

    private func starBadge(_ s: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.yellow)
            Text(s).font(.system(size: 11, weight: .semibold)).foregroundStyle(.yellow)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.yellow.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(Color.yellow.opacity(0.30), lineWidth: 1))
    }

    @ViewBuilder
    private func row(_ icon: String, _ color: Color, _ text: String,
                     tap: Bool = false, action: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color).frame(width: 18)
            Text(text).font(.system(size: 13))
                .foregroundStyle(tap ? color : .white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.07), lineWidth: 1)))
        .contentShape(Rectangle())
        .onTapGesture { if tap { action?() } }
    }

    @ViewBuilder
    private func actionBtn(_ label: String, _ icon: String,
                           _ gradient: [Color], action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                Text(label).font(.system(size: 14, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).opacity(0.55)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 17).padding(.vertical, 14)
            .background(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MapView (main screen)
// ─────────────────────────────────────────────────────────────────────────────

struct MapView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var loader = EcoMapLoader()

    @State private var filter:      MarkerCategory? = nil
    @State private var selected:    EcoMarker?      = nil
    @State private var panTo:       CLLocationCoordinate2D? = nil
    @State private var panAltitude: CLLocationDistance = 400_000
    @State private var continent:   Continent = .lebanon
    @State private var showSearch:  Bool   = false
    @State private var searchQuery: String = ""
    @State private var searchTask:  Task<Void, Never>? = nil
    @State private var showMapInfo: Bool   = false
    @State private var regionTask:  Task<Void, Never>? = nil  // debounce region changes

    private let green = Color(red: 0.08, green: 0.50, blue: 0.15)

    var body: some View {
        ZStack(alignment: .top) {

            NativeMapView(markers: loader.markers, filter: filter,
                          selected: $selected, panTo: $panTo, panAltitude: $panAltitude,
                          onRegionChanged: { coord, radiusKm in
                              // Only fetch when zoomed to city level or closer
                              // At continent zoom radiusKm is 1000s — ignore those pans
                              guard radiusKm < 150 else { return }
                              regionTask?.cancel()
                              regionTask = Task {
                                  try? await Task.sleep(for: .milliseconds(700))
                                  guard !Task.isCancelled else { return }
                                  await loader.load(lat: coord.latitude, lon: coord.longitude,
                                                    radiusKm: min(radiusKm, 80))
                              }
                          })
                .ignoresSafeArea()

            // iOS 26 frosted glass header
            VStack(spacing: 0) {

                // Title bar
                HStack(spacing: 12) {
                    Button { appState.screen = .home } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(green)
                    }

                    if showSearch {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.system(size: 13))
                            TextField("Search city, country, region…", text: $searchQuery)
                                .font(.system(size: 15))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .onSubmit { runSearch() }
                                .onChange(of: searchQuery) { _, q in
                                    searchTask?.cancel()
                                    guard q.count >= 3 else { return }
                                    searchTask = Task {
                                        try? await Task.sleep(for: .milliseconds(600))
                                        guard !Task.isCancelled else { return }
                                        await runSearchAsync(q)
                                    }
                                }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                showSearch = false; searchQuery = ""; searchTask?.cancel()
                            }
                        } label: {
                            Text("Cancel").font(.system(size: 14, weight: .semibold)).foregroundStyle(green)
                        }
                    } else {
                        Text("Eco Map").font(.custom("AlumniSans-Bold", size: 22)).foregroundStyle(green)
                        Spacer()
                        if loader.isLoading { ProgressView().tint(green).scaleEffect(0.82) }
                        Button { showMapInfo = true } label: {
                            Image(systemName: "info.circle").font(.system(size: 18)).foregroundStyle(.secondary)
                        }
                        Button {
                            withAnimation(.spring(response: 0.3)) { showSearch = true }
                        } label: {
                            Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundStyle(green)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background {
                    Rectangle().fill(.regularMaterial).ignoresSafeArea(edges: .top)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                        }
                }

                // Continent picker
                if !showSearch {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Continent.allCases) { c in
                                Button {
                                    continent = c; panAltitude = c.altitude; panTo = c.coordinate
                                    Task { await loader.load(lat: c.coordinate.latitude,
                                                             lon: c.coordinate.longitude,
                                                             radiusKm: c.radiusKm) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(c.flag).font(.system(size: 13))
                                        Text(c.rawValue)
                                            .font(.custom("AlumniSans-Bold", size: 13))
                                    }
                                    .foregroundStyle(continent == c ? .white : green)
                                    .padding(.horizontal, 13).padding(.vertical, 7)
                                    .background(continent == c ? green : green.opacity(0.10), in: Capsule())
                                    .overlay(Capsule().stroke(green, lineWidth: continent == c ? 0 : 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                    }
                    .background(.regularMaterial)

                    // Category chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", "globe", .gray, filter == nil) { filter = nil }
                            ForEach(MarkerCategory.allCases) { cat in
                                chip(cat.label, cat.sfSymbol, cat.color, filter == cat) {
                                    filter = (filter == cat) ? nil : cat
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 6)
                    }
                    .background(.regularMaterial.opacity(0.85))
                }

                // Error
                if let err = loader.errorMsg {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
                        Text(err).font(.system(size: 13)).lineLimit(2)
                        Spacer()
                        Button {
                            loader.errorMsg = nil
                            Task { await loader.load(lat: continent.coordinate.latitude,
                                                     lon: continent.coordinate.longitude,
                                                     radiusKm: continent.radiusKm) }
                        } label: {
                            Text("Retry")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Color.white.opacity(0.25), in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16).padding(.top, 5)
                }

                // Loading pill — shows while fetching, replaces pin count
                if loader.isLoading {
                    HStack(spacing: 6) {
                        ProgressView().tint(green).scaleEffect(0.75)
                        Text("Getting markers…")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .padding(.top, 6)
                } else if !loader.markers.isEmpty {
                    // Pin count
                    let count = filter == nil
                        ? loader.markers.count
                        : loader.markers.filter { $0.category == filter }.count
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill").font(.system(size: 10)).foregroundStyle(green)
                        Text("\(count) place\(count == 1 ? "" : "s")")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    .padding(.top, 6)
                }
            }

            // MapInfo overlay
            if showMapInfo {
                MapInfoOverlay(isShowing: $showMapInfo)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .sheet(item: $selected) { mk in
            MarkerDetailSheet(marker: mk)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(.clear)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if !appState.skipMapInfo { showMapInfo = true }
            await loader.load(lat: Continent.lebanon.coordinate.latitude,
                              lon: Continent.lebanon.coordinate.longitude,
                              radiusKm: Continent.lebanon.radiusKm)
        }
    }

    private func runSearch() {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        Task { await runSearchAsync(q) }
    }

    private func runSearchAsync(_ q: String) async {
        if let coord = await loader.search(query: q) {
            panAltitude = 300_000; panTo = coord
            withAnimation(.spring(response: 0.3)) { showSearch = false }
        }
    }

    @ViewBuilder
    private func chip(_ label: String, _ icon: String, _ color: Color, _ on: Bool,
                      action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.custom("AlumniSans-Bold", size: 13))
            }
            .foregroundStyle(on ? .white : color)
            .padding(.horizontal, 13).padding(.vertical, 7)
            .background(on ? color : color.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(color, lineWidth: on ? 0 : 1))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - MapInfoView (for Preferences navigation compatibility)
// ─────────────────────────────────────────────────────────────────────────────

struct MapInfoView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            appState.theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    backBtn { appState.screen = .home }.padding(.top, 8)
                    Text("Eco Map Guide")
                        .font(.custom("AlumniSans-Bold", size: 32))
                        .foregroundStyle(appState.theme.accent)
                    ForEach([
                        "Real eco-friendly places pulled live from OpenStreetMap worldwide.",
                        "Tap a continent to jump there and load local places.",
                        "Search any city, country, or region.",
                        "Filter by Stay, Cycling, or Nature.",
                        "Tap any pin for details, directions & website.",
                        "Tap ⓘ on the map to reopen this guide anytime.",
                    ], id: \.self) { tip in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(appState.theme.accent)
                            Text(tip).font(.custom("CreativeThoughts-Regular", size: 15))
                                .foregroundStyle(appState.theme.text)
                        }
                    }
                    Button {
                        appState.setSkipMapInfo(false)
                        appState.screen = .map
                    } label: {
                        Text("Open Map")
                            .font(.custom("AlumniSans-Bold", size: 20))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(appState.theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// backBtn and navBar are defined in FunctionalityView.swift and used app-wide.

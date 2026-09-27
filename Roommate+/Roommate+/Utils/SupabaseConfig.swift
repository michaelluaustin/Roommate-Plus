import Foundation

enum SupabaseConfig {
    private static let secrets: [String: Any] = {
        guard
            let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: path) as? [String: Any]
        else {
            return [:]
        }
        return dict
    }()

    static var supabaseURL: URL {
        guard let raw = secrets["SUPABASE_URL"] as? String else {
            fatalError("Missing Secrets.plist — copy Secrets.example.plist to Secrets.plist and add your Supabase URL.")
        }
        let base = normalizedProjectURL(from: raw)
        guard let url = URL(string: base) else {
            fatalError("Invalid SUPABASE_URL in Secrets.plist: \(raw)")
        }
        return url
    }

    static var supabaseKey: String {
        guard let key = secrets["SUPABASE_ANON_KEY"] as? String, !key.isEmpty else {
            fatalError("Missing SUPABASE_ANON_KEY in Secrets.plist — copy your publishable/anon key from the Supabase dashboard.")
        }
        return key
    }

    /// Public URL for a file in Supabase Storage (public buckets).
    static func publicStorageURL(bucket: String, path: String?, version: String? = nil) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        var base = supabaseURL.absoluteString
        while base.hasSuffix("/") { base.removeLast() }
        var urlString = "\(base)/storage/v1/object/public/\(bucket)/\(path)"
        if let version, !version.isEmpty {
            let encoded = version.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? version
            urlString += "?v=\(encoded)"
        }
        return URL(string: urlString)
    }

    /// Accepts either the project root or a REST URL from .env files.
    private static func normalizedProjectURL(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        if value.hasSuffix("/rest/v1") {
            value.removeLast("/rest/v1".count)
        }
        return value
    }
}

import Foundation

/// Parses Postgres/ISO8601 timestamp strings returned by Supabase into Date.
///
/// We decode timestamp columns as raw String in the Codable models and convert
/// here, rather than relying on the JSON decoder's date strategy. Supabase can
/// return timestamps with fractional seconds, without them, or in Postgres'
/// space-separated form, and a single decoder strategy fails on the others —
/// a format mismatch would fail the entire row decode. Strings always decode.
enum SupabaseDate {
    static func parse(_ value: String?) -> Date? {
        guard let str = value, !str.isEmpty else { return nil }

        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: str) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: str) { return date }

        // Postgres default "2026-06-30 11:32:00" (space separator, no TZ)
        let postgres = DateFormatter()
        postgres.dateFormat = "yyyy-MM-dd HH:mm:ss"
        postgres.timeZone = TimeZone(identifier: "UTC")
        postgres.locale = Locale(identifier: "en_US_POSIX")
        return postgres.date(from: str)
    }

    /// Format a Date as an ISO8601 string for writing to Supabase.
    static func string(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

import Foundation
import Supabase

/// Live sync across phones. Subscribes to Postgres changes on the household's
/// `items` and `users` rows; on any change, calls `onChange` so the UI can
/// refetch. We refetch wholesale rather than applying deltas — for a 3-4 person
/// household the payload is tiny, and "refetch on any change" is far simpler and
/// less bug-prone than reconciling individual insert/update/delete events.
///
/// SETUP REQUIRED: Realtime must be enabled for the `items` and `users` tables
/// in the Supabase dashboard (Database → Replication, add tables to the
/// `supabase_realtime` publication). Without that, no events fire.
@MainActor
final class RealtimeService {
    private let supabase: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    /// Begin listening for changes scoped to one household.
    func start(householdId: String, onChange: @escaping @Sendable () async -> Void) {
        stop()

        listenTask = Task {
            let channel = supabase.channel("household-\(householdId)")
            self.channel = channel

            // Streams must be created before subscribe().
            let itemChanges = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "items",
                filter: "household_id=eq.\(householdId)"
            )
            let userChanges = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "users",
                filter: "household_id=eq.\(householdId)"
            )

            await channel.subscribe()

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in itemChanges { await onChange() }
                }
                group.addTask {
                    for await _ in userChanges { await onChange() }
                }
            }
        }
    }

    /// Stop listening and tear down the channel.
    func stop() {
        listenTask?.cancel()
        listenTask = nil

        if let channel {
            Task { await supabase.removeChannel(channel) }
        }
        channel = nil
    }
}

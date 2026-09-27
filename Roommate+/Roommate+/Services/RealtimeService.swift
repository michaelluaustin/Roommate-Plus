import Foundation
import Supabase

/// Live sync across phones. Subscribes to Postgres changes for the household;
/// on any change, calls `onChange` so the UI can refetch. We refetch wholesale
/// rather than applying deltas — for a small household the payload is tiny, and
/// "refetch on any change" is simpler and less bug-prone than reconciling events.
///
/// SETUP REQUIRED: tables must be in the `supabase_realtime` publication.
/// Re-run `supabase/rls_policies.sql` (or the realtime section) in the SQL Editor.
@MainActor
final class RealtimeService {
    private let supabase: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var listenTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

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
            let expenseChanges = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "expenses",
                filter: "household_id=eq.\(householdId)"
            )
            // No household_id column — listen broadly; refetch is household-scoped.
            let participantChanges = channel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "expense_participants"
            )

            await channel.subscribe()

            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    for await _ in itemChanges { await self.scheduleChange(onChange) }
                }
                group.addTask {
                    for await _ in userChanges { await self.scheduleChange(onChange) }
                }
                group.addTask {
                    for await _ in expenseChanges { await self.scheduleChange(onChange) }
                }
                group.addTask {
                    for await _ in participantChanges { await self.scheduleChange(onChange) }
                }
            }
        }
    }

    /// Coalesce bursts of realtime events into one refetch.
    private func scheduleChange(_ onChange: @escaping @Sendable () async -> Void) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            await onChange()
        }
    }

    /// Stop listening and tear down the channel.
    func stop() {
        debounceTask?.cancel()
        debounceTask = nil
        listenTask?.cancel()
        listenTask = nil

        if let channel {
            Task { await supabase.removeChannel(channel) }
        }
        channel = nil
    }
}

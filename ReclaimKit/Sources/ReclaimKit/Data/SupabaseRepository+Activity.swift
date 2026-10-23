import Foundation
import Supabase

/// The lock screen, from the server's side (migration 0015 and the
/// `start-live-activity` Edge Function).
extension SupabaseRepository {

    public func saveActivityToken(_ token: String, environment: String) async throws {
        struct P: Encodable { let p_token: String; let p_environment: String }
        try await client.rpc("save_activity_token",
                             params: P(p_token: token, p_environment: environment)).execute()
    }

    /// The body goes as bytes, already encoded: the dates in it have to be
    /// exactly what ActivityKit decodes (`RemoteActivity`).
    public func startActivityRemotely(body: Data) async throws {
        try await client.functions.invoke("start-live-activity",
                                          options: FunctionInvokeOptions(body: body))
    }
}

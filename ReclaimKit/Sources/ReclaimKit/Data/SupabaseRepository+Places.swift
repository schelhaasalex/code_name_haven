import Foundation
import Supabase

/// The box's place, split from `SupabaseRepository` so neither file is a long
/// one: reading places by named columns — never every column, see
/// `Place.readableColumns` — naming one, and finding or making a box's.
extension SupabaseRepository {

    public func myPlaces() async throws -> [Place] {
        try await client.from("places").select(Place.readableColumns)
            .is("merged_into", value: nil)
            .order("created_at", ascending: false)
            .execute().value
    }

    /// Nothing back: the library's default asks for the whole row, and a
    /// phone may not read the box's secret in it (`join_secret_hash`), so
    /// every rename was refused — and every box went unnamed on the server.
    public func rename(place id: UUID, to name: String) async throws {
        struct Row: Encodable { let name: String }
        try await client.from("places").update(Row(name: name), returning: .minimal)
            .eq("id", value: id).execute()
    }

    public func dockPlace(secret: String, handle: String) async throws -> UUID? {
        struct P: Encodable { let p_secret: String; let p_handle: String }
        return try await client.rpc("dock_place", params: P(p_secret: secret, p_handle: handle))
            .execute().value
    }
}

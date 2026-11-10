import Foundation
import Supabase

/// The box's place, split from `SupabaseRepository` so neither file is a long
/// one: reading places by named columns — never every column, see
/// `Place.readableColumns` — naming one, finding or making a box's, and a
/// box's code for another phone.
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

    /// A phone's code that has run out comes back as `RC410` (0025), never
    /// as a new box: it is `DockError.codeRanOut` here.
    public func dockPlace(secret: String, handle: String) async throws -> UUID? {
        struct P: Encodable { let p_secret: String; let p_handle: String }
        do {
            return try await client.rpc("dock_place", params: P(p_secret: secret, p_handle: handle))
                .execute().value
        } catch let error as PostgrestError where error.code == DockError.ranOutCode {
            throw DockError.codeRanOut
        }
    }

    public func boxCode(place: UUID) async throws -> String {
        struct P: Encodable { let p_place: UUID }
        return try await client.rpc("box_code", params: P(p_place: place)).execute().value
    }
}

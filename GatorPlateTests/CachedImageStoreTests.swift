import Foundation
import Testing
@testable import GatorPlate

private actor CountingImageStore: ImageStore {
    private(set) var loads = 0
    private(set) var saves = 0
    private var images: [String: Data]

    init(images: [String: Data] = [:]) { self.images = images }

    func save(jpeg: Data, forPostID postID: String) async throws {
        saves += 1
        images[postID] = jpeg
    }

    func load(forPostID postID: String) async throws -> Data? {
        loads += 1
        return images[postID]
    }
}

struct CachedImageStoreTests {
    @Test func secondLoadComesFromTheCache() async throws {
        let base = CountingImageStore(images: ["a": Data([1, 2, 3])])
        let store = CachedImageStore(wrapping: base)
        #expect(try await store.load(forPostID: "a") == Data([1, 2, 3]))
        #expect(try await store.load(forPostID: "a") == Data([1, 2, 3]))
        #expect(await base.loads == 1)
    }

    @Test func missingPhotosAreNotCached() async throws {
        let base = CountingImageStore()
        let store = CachedImageStore(wrapping: base)
        #expect(try await store.load(forPostID: "none") == nil)
        #expect(try await store.load(forPostID: "none") == nil)
        #expect(await base.loads == 2)
    }

    @Test func savedPhotosAreServedWithoutAReload() async throws {
        let base = CountingImageStore()
        let store = CachedImageStore(wrapping: base)
        try await store.save(jpeg: Data([9]), forPostID: "a")
        #expect(try await store.load(forPostID: "a") == Data([9]))
        #expect(await base.saves == 1)
        #expect(await base.loads == 0)
    }
}

import CoreData
import Foundation

final class CoreDataRetentionStore: RetentionSettingsStoring {
    private let configuration: RetentionStoreConfiguration
    private let fileManager: FileManager
    private let persistentContainer: NSPersistentContainer
    private let longText: LongTextFileStore
    private var latestCleanupResult: RetentionCleanupResult?

    init(
        configuration: RetentionStoreConfiguration = .default(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.longText = LongTextFileStore(
            directoryURL: configuration.storeURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("LongText", isDirectory: true)
        )
        self.persistentContainer = NSPersistentContainer(
            name: configuration.modelName,
            managedObjectModel: Self.makeManagedObjectModel(named: configuration.modelName)
        )

        prepareDirectoriesIfNeeded()
        loadPersistentStore()
    }

    var snapshot: RetentionPersistenceSnapshot {
        loadSnapshot()
    }

    func storedClip(for id: String) -> RetentionManagedClip? {
        performFetch {
            fetchClipObject(id: id, in: $0).flatMap { Self.makeManagedClip(from: $0, longText: longText) }
        }
    }

    @discardableResult
    func saveRetentionSettings(_ settings: RetentionSettings) -> RetentionPersistenceSnapshot {
        performMutation { context in
            guard let object = fetchSingletonObject(
                entityName: Self.retentionSettingsEntityName,
                in: context
            ) else {
                return
            }
            object.setValue(Int64(settings.maxItemCount), forKey: "maxItemCount")
            object.setValue(settings.ttlPolicy.rawValue, forKey: "ttlPolicyRawValue")
            object.setValue(settings.clearOnQuit, forKey: "clearOnQuit")
            object.setValue(settings.bumpPastedItemToFront, forKey: "bumpPastedItemToFront")
            object.setValue(settings.lastUpdatedAt, forKey: "updatedAt")
        }
    }

    @discardableResult
    func saveAssetCacheSettings(_ settings: AssetCacheSettings) -> RetentionPersistenceSnapshot {
        performMutation { context in
            guard let object = fetchSingletonObject(
                entityName: Self.assetCacheSettingsEntityName,
                in: context
            ) else {
                return
            }
            object.setValue(Int64(settings.maxCacheSizeMB), forKey: "maxCacheSizeMB")
            object.setValue(settings.currentUsageBytes, forKey: "currentUsageBytes")
            object.setValue(settings.lastClearedAt, forKey: "lastClearedAt")
            object.setValue(settings.lastSweepAt, forKey: "lastSweepAt")
        }
    }

    @discardableResult
    func replaceStoredClips(_ clips: [RetentionManagedClip]) -> RetentionPersistenceSnapshot {
        let incomingIDs = Set(clips.map(\.id))
        var keptFiles = Set<String>()
        // Superseded long-text files go only after the rows that point at the
        // new ones are saved.
        return performMutation(afterSave: { self.longText.prune(keeping: keptFiles) }) { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.clipEntityName)
            let existingObjects = (try? context.fetch(request)) ?? []
            // The bulk fetch above already has every stored object, so index it
            // instead of running one predicate fetch per clip.
            var objectsByID: [String: NSManagedObject] = [:]
            objectsByID.reserveCapacity(existingObjects.count)

            for object in existingObjects {
                let id = (object.value(forKey: "id") as? String) ?? ""
                // Nothing constrains the id column, so drop rows this pass no
                // longer stores and any second row for an id already seen.
                guard incomingIDs.contains(id), objectsByID[id] == nil else {
                    context.delete(object)
                    continue
                }
                objectsByID[id] = object
            }

            for clip in clips {
                if let object = objectsByID[clip.id] {
                    if let file = Self.populate(object: object, with: clip, longText: longText) {
                        keptFiles.insert(file)
                    }
                } else {
                    let object = NSEntityDescription.insertNewObject(
                        forEntityName: Self.clipEntityName,
                        into: context
                    )
                    objectsByID[clip.id] = object
                    if let file = Self.populate(object: object, with: clip, longText: longText) {
                        keptFiles.insert(file)
                    }
                }
            }
        }
    }

    @discardableResult
    func upsertStoredClips(_ clips: [RetentionManagedClip]) -> RetentionPersistenceSnapshot {
        var keptFiles = Set<String>()
        let upsertedIDs = clips.map(\.id)
        return performMutation(afterSave: {
            self.longText.prune(keeping: keptFiles, forIDs: upsertedIDs)
        }) { context in
            for clip in clips {
                let object = fetchClipObject(id: clip.id, in: context)
                    ?? NSEntityDescription.insertNewObject(
                        forEntityName: Self.clipEntityName,
                        into: context
                    )
                if let file = Self.populate(object: object, with: clip, longText: longText) {
                    keptFiles.insert(file)
                }
            }
        }
    }

    @discardableResult
    func removeStoredClips(ids: [String]) -> RetentionPersistenceSnapshot {
        guard ids.isEmpty == false else {
            return snapshot
        }

        let idsToRemove = Set(ids)
        return performMutation(afterSave: { self.longText.remove(ids: ids) }) { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.clipEntityName)
            request.predicate = NSPredicate(format: "id IN %@", Array(idsToRemove))
            let objects = (try? context.fetch(request)) ?? []
            for object in objects {
                context.delete(object)
            }
        }
    }

    @discardableResult
    func saveLatestCleanupResult(_ result: RetentionCleanupResult?) -> RetentionPersistenceSnapshot {
        latestCleanupResult = result
        return snapshot
    }

    private func loadSnapshot() -> RetentionPersistenceSnapshot {
        performFetch { context in
            let retentionSettings = fetchRetentionSettings(in: context)
            let assetCacheSettings = fetchAssetCacheSettings(in: context)
            // Collapse any duplicate id already on disk so the rest of the app
            // sees one clip per id until replaceStoredClips deletes the extra.
            var seenIDs = Set<String>()
            let clips = fetchStoredClips(in: context).filter { seenIDs.insert($0.id).inserted }
            return RetentionPersistenceSnapshot(
                retentionSettings: retentionSettings,
                assetCacheSettings: assetCacheSettings,
                storedClips: clips,
                latestCleanupResult: latestCleanupResult
            )
        }
    }

    private func fetchRetentionSettings(in context: NSManagedObjectContext) -> RetentionSettings {
        guard let object = fetchSingletonObject(
            entityName: Self.retentionSettingsEntityName,
            in: context,
            insertsIfMissing: false
        ) else {
            return RetentionSettings()
        }

        return RetentionSettings(
            maxItemCount: Int(object.value(forKey: "maxItemCount") as? Int64 ?? Int64(RetentionSettingBounds.defaultItemCount)),
            ttlPolicy: RetentionTTLPolicy(
                rawValue: object.value(forKey: "ttlPolicyRawValue") as? String ?? RetentionTTLPolicy.oneMonth.rawValue
            ) ?? .oneMonth,
            clearOnQuit: object.value(forKey: "clearOnQuit") as? Bool ?? false,
            bumpPastedItemToFront: object.value(forKey: "bumpPastedItemToFront") as? Bool ?? true,
            lastUpdatedAt: object.value(forKey: "updatedAt") as? Date ?? .now
        )
    }

    private func fetchAssetCacheSettings(in context: NSManagedObjectContext) -> AssetCacheSettings {
        guard let object = fetchSingletonObject(
            entityName: Self.assetCacheSettingsEntityName,
            in: context,
            insertsIfMissing: false
        ) else {
            return AssetCacheSettings()
        }

        return AssetCacheSettings(
            maxCacheSizeMB: Int(object.value(forKey: "maxCacheSizeMB") as? Int64 ?? Int64(RetentionSettingBounds.defaultCacheSizeMB)),
            currentUsageBytes: object.value(forKey: "currentUsageBytes") as? Int64 ?? 0,
            lastClearedAt: object.value(forKey: "lastClearedAt") as? Date,
            lastSweepAt: object.value(forKey: "lastSweepAt") as? Date
        )
    }

    private func fetchStoredClips(in context: NSManagedObjectContext) -> [RetentionManagedClip] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.clipEntityName)
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastCopiedAt", ascending: false),
            NSSortDescriptor(key: "capturedAt", ascending: false),
            NSSortDescriptor(key: "id", ascending: false)
        ]
        let objects = (try? context.fetch(request)) ?? []
        return objects.compactMap { Self.makeManagedClip(from: $0, longText: longText) }
    }

    private func fetchSingletonObject(
        entityName: String,
        in context: NSManagedObjectContext,
        insertsIfMissing: Bool = true
    ) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
        request.fetchLimit = 1

        if let object = try? context.fetch(request).first {
            return object
        }

        guard insertsIfMissing else {
            return nil
        }

        return NSEntityDescription.insertNewObject(forEntityName: entityName, into: context)
    }

    private func fetchClipObject(id: String, in context: NSManagedObjectContext) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.clipEntityName)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id)
        return try? context.fetch(request).first
    }

    private func performFetch<T>(_ work: (NSManagedObjectContext) -> T) -> T {
        let context = persistentContainer.viewContext
        var value: T?
        context.performAndWait {
            value = work(context)
        }
        return value!
    }

    private func performMutation(
        afterSave: (() -> Void)? = nil,
        _ work: (NSManagedObjectContext) -> Void
    ) -> RetentionPersistenceSnapshot {
        let context = persistentContainer.viewContext
        context.performAndWait {
            work(context)
            if context.hasChanges {
                guard (try? context.save()) != nil else { return }
            }
            afterSave?()
        }
        return loadSnapshot()
    }

    private func prepareDirectoriesIfNeeded() {
        let databaseDirectory = configuration.storeURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: configuration.assetCacheDirectoryURL, withIntermediateDirectories: true)
    }

    private func loadPersistentStore() {
        let description = NSPersistentStoreDescription(url: configuration.storeURL)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.loadPersistentStores { _, _ in }
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        persistentContainer.viewContext.undoManager = nil
    }

    @discardableResult
    private static func populate(
        object: NSManagedObject,
        with clip: RetentionManagedClip,
        longText: LongTextFileStore
    ) -> String? {
        let spilled = longText.spillIfNeeded(id: clip.id, text: clip.titleText)
        object.setValue(clip.id, forKey: "id")
        object.setValue(clip.normalizedHash, forKey: "normalizedHash")
        object.setValue(clip.kind.rawValue, forKey: "kind")
        object.setValue(clip.capturedAt, forKey: "capturedAt")
        object.setValue(clip.lastCopiedAt, forKey: "lastCopiedAt")
        object.setValue(clip.isPinned, forKey: "isPinned")
        object.setValue(clip.pinnedAt, forKey: "pinnedAt")
        object.setValue(spilled.storedText, forKey: "titleText")
        object.setValue(clip.secondaryText, forKey: "secondaryText")
        object.setValue(clip.metadataText, forKey: "metadataText")
        object.setValue(clip.secondaryBadgeText, forKey: "secondaryBadgeText")
        object.setValue(clip.sourceAppBundleID, forKey: "sourceAppBundleID")
        object.setValue(clip.sourceAppDisplayName, forKey: "sourceAppDisplayName")
        object.setValue(clip.sourceAppSymbolName, forKey: "sourceAppSymbolName")
        object.setValue(clip.sourceAppAccentToken, forKey: "sourceAppAccentToken")
        object.setValue(clip.previewStyleKey, forKey: "previewStyleKey")
        object.setValue(clip.previewStyleHint, forKey: "previewStyleHint")
        object.setValue(encodeStringArray(clip.filePaths), forKey: "filePathsBlob")
        object.setValue(encodeStringArray(clip.colorSwatches), forKey: "colorSwatchesBlob")
        object.setValue(clip.richTextAvailable, forKey: "richTextAvailable")
        object.setValue(clip.estimatedByteSize, forKey: "estimatedByteSize")
        object.setValue(clip.assetCacheKey, forKey: "assetCacheKey")
        return spilled.fileName
    }

    private nonisolated static func makeManagedClip(
        from object: NSManagedObject,
        longText: LongTextFileStore
    ) -> RetentionManagedClip? {
        guard
            let id = object.value(forKey: "id") as? String,
            let normalizedHash = object.value(forKey: "normalizedHash") as? String,
            let rawKind = object.value(forKey: "kind") as? String,
            let kind = RetentionClipKind(rawValue: rawKind),
            let capturedAt = object.value(forKey: "capturedAt") as? Date,
            let lastCopiedAt = object.value(forKey: "lastCopiedAt") as? Date,
            let titleText = object.value(forKey: "titleText") as? String,
            let metadataText = object.value(forKey: "metadataText") as? String,
            let sourceAppDisplayName = object.value(forKey: "sourceAppDisplayName") as? String,
            let sourceAppAccentToken = object.value(forKey: "sourceAppAccentToken") as? String,
            let previewStyleKey = object.value(forKey: "previewStyleKey") as? String
        else {
            return nil
        }

        return RetentionManagedClip(
            id: id,
            normalizedHash: normalizedHash,
            kind: kind,
            capturedAt: capturedAt,
            lastCopiedAt: lastCopiedAt,
            isPinned: object.value(forKey: "isPinned") as? Bool ?? false,
            pinnedAt: object.value(forKey: "pinnedAt") as? Date,
            titleText: longText.restore(id: id, storedText: titleText),
            secondaryText: object.value(forKey: "secondaryText") as? String,
            metadataText: metadataText,
            secondaryBadgeText: object.value(forKey: "secondaryBadgeText") as? String,
            sourceAppBundleID: object.value(forKey: "sourceAppBundleID") as? String,
            sourceAppDisplayName: sourceAppDisplayName,
            sourceAppSymbolName: object.value(forKey: "sourceAppSymbolName") as? String,
            sourceAppAccentToken: sourceAppAccentToken,
            previewStyleKey: previewStyleKey,
            previewStyleHint: object.value(forKey: "previewStyleHint") as? String,
            filePaths: decodeStringArray(object.value(forKey: "filePathsBlob") as? Data),
            colorSwatches: decodeStringArray(object.value(forKey: "colorSwatchesBlob") as? Data),
            richTextAvailable: object.value(forKey: "richTextAvailable") as? Bool ?? false,
            estimatedByteSize: object.value(forKey: "estimatedByteSize") as? Int64 ?? 0,
            assetCacheKey: object.value(forKey: "assetCacheKey") as? String
        )
    }

    private static func encodeStringArray(_ values: [String]) -> Data? {
        try? JSONEncoder().encode(values)
    }

    private nonisolated static func decodeStringArray(_ data: Data?) -> [String] {
        guard let data else {
            return []
        }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    private static func makeManagedObjectModel(named name: String) -> NSManagedObjectModel {
        if let modelURL = Bundle.main.url(forResource: name, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            return model
        }

        let model = NSManagedObjectModel()
        model.entities = [
            makeClipEntity(),
            makeRetentionSettingsEntity(),
            makeAssetCacheSettingsEntity()
        ]
        return model
    }

    private static func makeClipEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = clipEntityName
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            makeAttribute(name: "id", type: .stringAttributeType),
            makeAttribute(name: "normalizedHash", type: .stringAttributeType),
            makeAttribute(name: "kind", type: .stringAttributeType),
            makeAttribute(name: "capturedAt", type: .dateAttributeType),
            makeAttribute(name: "lastCopiedAt", type: .dateAttributeType),
            makeAttribute(name: "isPinned", type: .booleanAttributeType, optional: false, defaultValue: false),
            makeAttribute(name: "pinnedAt", type: .dateAttributeType, optional: true),
            makeAttribute(name: "titleText", type: .stringAttributeType),
            makeAttribute(name: "secondaryText", type: .stringAttributeType, optional: true),
            makeAttribute(name: "metadataText", type: .stringAttributeType),
            makeAttribute(name: "secondaryBadgeText", type: .stringAttributeType, optional: true),
            makeAttribute(name: "sourceAppBundleID", type: .stringAttributeType, optional: true),
            makeAttribute(name: "sourceAppDisplayName", type: .stringAttributeType),
            makeAttribute(name: "sourceAppSymbolName", type: .stringAttributeType, optional: true),
            makeAttribute(name: "sourceAppAccentToken", type: .stringAttributeType),
            makeAttribute(name: "previewStyleKey", type: .stringAttributeType),
            makeAttribute(name: "previewStyleHint", type: .stringAttributeType, optional: true),
            makeAttribute(name: "filePathsBlob", type: .binaryDataAttributeType, optional: true),
            makeAttribute(name: "colorSwatchesBlob", type: .binaryDataAttributeType, optional: true),
            makeAttribute(name: "richTextAvailable", type: .booleanAttributeType, optional: false, defaultValue: false),
            makeAttribute(name: "estimatedByteSize", type: .integer64AttributeType, optional: false, defaultValue: 0),
            makeAttribute(name: "assetCacheKey", type: .stringAttributeType, optional: true)
        ]
        return entity
    }

    private static func makeRetentionSettingsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = retentionSettingsEntityName
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            makeAttribute(name: "maxItemCount", type: .integer64AttributeType, optional: false, defaultValue: Int64(RetentionSettingBounds.defaultItemCount)),
            makeAttribute(name: "ttlPolicyRawValue", type: .stringAttributeType, optional: false, defaultValue: RetentionTTLPolicy.oneMonth.rawValue),
            makeAttribute(name: "clearOnQuit", type: .booleanAttributeType, optional: false, defaultValue: false),
            makeAttribute(name: "bumpPastedItemToFront", type: .booleanAttributeType, optional: false, defaultValue: true),
            makeAttribute(name: "updatedAt", type: .dateAttributeType)
        ]
        return entity
    }

    private static func makeAssetCacheSettingsEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = assetCacheSettingsEntityName
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            makeAttribute(name: "maxCacheSizeMB", type: .integer64AttributeType, optional: false, defaultValue: Int64(RetentionSettingBounds.defaultCacheSizeMB)),
            makeAttribute(name: "currentUsageBytes", type: .integer64AttributeType, optional: false, defaultValue: 0),
            makeAttribute(name: "lastClearedAt", type: .dateAttributeType, optional: true),
            makeAttribute(name: "lastSweepAt", type: .dateAttributeType, optional: true)
        ]
        return entity
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static let clipEntityName = "ClipItemRecord"
    private static let retentionSettingsEntityName = "RetentionSettingsRecord"
    private static let assetCacheSettingsEntityName = "AssetCacheSettingsRecord"
}

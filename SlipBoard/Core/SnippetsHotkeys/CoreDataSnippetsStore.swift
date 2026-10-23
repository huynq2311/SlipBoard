import CoreData
import Foundation

final class CoreDataSnippetsStore: SnippetStoring {
    private nonisolated static let logger = DiagnosticLogger(category: "Snippets")
    struct Configuration: Hashable {
        var modelName: String
        var storeURL: URL

        static func `default`(fileManager: FileManager = .default) -> Configuration {
            let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            let slipBoardURL = baseURL.appendingPathComponent("SlipBoard", isDirectory: true)
            let databaseURL = slipBoardURL.appendingPathComponent("Database", isDirectory: true)

            return Configuration(
                modelName: "SlipBoard",
                storeURL: databaseURL.appendingPathComponent("SlipBoard.sqlite")
            )
        }
    }

    private let configuration: Configuration
    private let fileManager: FileManager
    private let persistentContainer: NSPersistentContainer
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var snippets: [SnippetRecord]
    private(set) var globalBindings: [GlobalHotkeyBinding]

    init(
        configuration: Configuration = .default(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.persistentContainer = NSPersistentContainer(
            name: configuration.modelName,
            managedObjectModel: Self.makeManagedObjectModel(named: configuration.modelName)
        )
        self.snippets = []
        self.globalBindings = []

        prepareDirectoriesIfNeeded()
        loadPersistentStore()
        reloadSnapshot()
    }

    func snippet(id: SnippetID) -> SnippetRecord? {
        snippets.first(where: { $0.id == id })
    }

    @discardableResult
    func replaceSnippets(_ snippets: [SnippetRecord]) -> [SnippetRecord] {
        performMutation { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.snippetEntityName)
            let existingObjects = (try? context.fetch(request)) ?? []
            let incomingIDs = Set(snippets.map(\.id.rawValue))

            for object in existingObjects where incomingIDs.contains((object.value(forKey: "id") as? String) ?? "") == false {
                context.delete(object)
            }

            for snippet in snippets {
                let object = fetchSnippetObject(id: snippet.id, in: context)
                    ?? NSEntityDescription.insertNewObject(
                        forEntityName: Self.snippetEntityName,
                        into: context
                    )
                populateSnippetObject(object, with: snippet)
            }
        }

        return self.snippets
    }

    @discardableResult
    func saveSnippet(_ snippet: SnippetRecord) -> SnippetRecord {
        performMutation { context in
            let object = fetchSnippetObject(id: snippet.id, in: context)
                ?? NSEntityDescription.insertNewObject(
                    forEntityName: Self.snippetEntityName,
                    into: context
                )
            populateSnippetObject(object, with: snippet)
        }

        return self.snippet(id: snippet.id) ?? snippet
    }

    @discardableResult
    func deleteSnippet(id: SnippetID) -> SnippetRecord? {
        let removedRecord = snippet(id: id)
        guard removedRecord != nil else {
            return nil
        }

        performMutation { context in
            if let object = fetchSnippetObject(id: id, in: context) {
                context.delete(object)
            }
        }

        return removedRecord
    }

    @discardableResult
    func replaceGlobalBindings(_ bindings: [GlobalHotkeyBinding]) -> [GlobalHotkeyBinding] {
        performMutation { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.globalBindingEntityName)
            let existingObjects = (try? context.fetch(request)) ?? []
            let incomingCommandIDs = Set(bindings.map(\.commandID.rawValue))

            for object in existingObjects where incomingCommandIDs.contains((object.value(forKey: "commandIDRawValue") as? String) ?? "") == false {
                context.delete(object)
            }

            for binding in bindings {
                let object = fetchGlobalBindingObject(commandID: binding.commandID, in: context)
                    ?? NSEntityDescription.insertNewObject(
                        forEntityName: Self.globalBindingEntityName,
                        into: context
                    )
                populateGlobalBindingObject(object, with: binding)
            }
        }

        return globalBindings
    }

    @discardableResult
    func saveGlobalBinding(_ binding: GlobalHotkeyBinding) -> GlobalHotkeyBinding {
        performMutation { context in
            let object = fetchGlobalBindingObject(commandID: binding.commandID, in: context)
                ?? NSEntityDescription.insertNewObject(
                    forEntityName: Self.globalBindingEntityName,
                    into: context
                )
            populateGlobalBindingObject(object, with: binding)
        }

        return globalBindings.first(where: { $0.commandID == binding.commandID }) ?? binding
    }

    private func reloadSnapshot() {
        snippets = performFetch(fetchSnippets)
        globalBindings = performFetch(fetchGlobalBindings)
    }

    private func fetchSnippets(in context: NSManagedObjectContext) -> [SnippetRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.snippetEntityName)
        request.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "updatedAt", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false),
            NSSortDescriptor(key: "title", ascending: true)
        ]
        let objects = (try? context.fetch(request)) ?? []
        return objects.compactMap(makeSnippetRecord(from:))
    }

    private func fetchGlobalBindings(in context: NSManagedObjectContext) -> [GlobalHotkeyBinding] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.globalBindingEntityName)
        let objects = (try? context.fetch(request)) ?? []
        let bindings = objects.compactMap(makeGlobalBinding(from:))

        return GlobalHotkeyCommandID.allCases.compactMap { commandID in
            bindings.first(where: { $0.commandID == commandID })
        }
    }

    private func fetchSnippetObject(
        id: SnippetID,
        in context: NSManagedObjectContext
    ) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.snippetEntityName)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id.rawValue)
        return try? context.fetch(request).first
    }

    private func fetchGlobalBindingObject(
        commandID: GlobalHotkeyCommandID,
        in context: NSManagedObjectContext
    ) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.globalBindingEntityName)
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "commandIDRawValue == %@", commandID.rawValue)
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

    private func performMutation(_ work: (NSManagedObjectContext) -> Void) {
        let context = persistentContainer.viewContext
        context.performAndWait {
            work(context)
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    Self.logger.error("Snippets store could not save: \(DiagnosticLogger.describe(error))")
                }
            }
        }
        reloadSnapshot()
    }

    private func prepareDirectoriesIfNeeded() {
        let databaseDirectory = configuration.storeURL.deletingLastPathComponent()
        try? fileManager.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
    }

    private func loadPersistentStore() {
        let description = NSPersistentStoreDescription(url: configuration.storeURL)
        description.shouldInferMappingModelAutomatically = true
        description.shouldMigrateStoreAutomatically = true
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.loadPersistentStores { _, error in
            if let error {
                Self.logger.error("Snippets store could not load: \(DiagnosticLogger.describe(error))")
            }
        }
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        persistentContainer.viewContext.undoManager = nil
    }

    private func populateSnippetObject(_ object: NSManagedObject, with snippet: SnippetRecord) {
        object.setValue(snippet.id.rawValue, forKey: "id")
        object.setValue(snippet.title, forKey: "title")
        object.setValue(snippet.content, forKey: "content")
        object.setValue(snippet.kind.rawValue, forKey: "kindRawValue")
        object.setValue(snippet.createdAt, forKey: "createdAt")
        object.setValue(snippet.updatedAt, forKey: "updatedAt")
        object.setValue(snippet.isPinned, forKey: "isPinned")
        applyHotkey(snippet.hotkey, to: object, prefix: "hotkey")
    }

    private func makeSnippetRecord(from object: NSManagedObject) -> SnippetRecord? {
        guard
            let id = object.value(forKey: "id") as? String,
            let title = object.value(forKey: "title") as? String,
            let content = object.value(forKey: "content") as? String,
            let rawKind = object.value(forKey: "kindRawValue") as? String,
            let kind = SnippetContentKind(rawValue: rawKind),
            let createdAt = object.value(forKey: "createdAt") as? Date,
            let updatedAt = object.value(forKey: "updatedAt") as? Date
        else {
            return nil
        }

        return SnippetRecord(
            id: SnippetID(rawValue: id),
            title: title,
            content: content,
            kind: kind,
            hotkey: readHotkey(from: object, prefix: "hotkey"),
            createdAt: createdAt,
            updatedAt: updatedAt,
            isPinned: object.value(forKey: "isPinned") as? Bool ?? false
        )
    }

    private func populateGlobalBindingObject(_ object: NSManagedObject, with binding: GlobalHotkeyBinding) {
        object.setValue(binding.commandID.rawValue, forKey: "commandIDRawValue")
        object.setValue(binding.availability.rawValue, forKey: "availabilityRawValue")
        object.setValue(binding.detailText, forKey: "detailText")
        applyHotkey(binding.hotkey, to: object, prefix: "hotkey")
    }

    private func makeGlobalBinding(from object: NSManagedObject) -> GlobalHotkeyBinding? {
        guard
            let rawCommandID = object.value(forKey: "commandIDRawValue") as? String,
            let commandID = GlobalHotkeyCommandID(rawValue: rawCommandID)
        else {
            return nil
        }

        return GlobalHotkeyBinding(
            commandID: commandID,
            hotkey: readHotkey(from: object, prefix: "hotkey"),
            availability: HotkeyRuntimeAvailability(
                rawValue: object.value(forKey: "availabilityRawValue") as? String ?? HotkeyRuntimeAvailability.enabled.rawValue
            ) ?? .enabled,
            detailText: object.value(forKey: "detailText") as? String
        )
    }

    private func applyHotkey(
        _ descriptor: HotkeyDescriptor?,
        to object: NSManagedObject,
        prefix: String
    ) {
        object.setValue(descriptor.map { Int64($0.keyCode) }, forKey: "\(prefix)KeyCode")
        object.setValue(descriptor?.keyEquivalent, forKey: "\(prefix)KeyEquivalent")
        object.setValue(descriptor?.displayLabel, forKey: "\(prefix)DisplayLabel")
        object.setValue(encodeModifiers(descriptor?.modifiers ?? []), forKey: "\(prefix)ModifiersBlob")
    }

    private func readHotkey(
        from object: NSManagedObject,
        prefix: String
    ) -> HotkeyDescriptor? {
        guard
            let keyEquivalent = object.value(forKey: "\(prefix)KeyEquivalent") as? String,
            keyEquivalent.isEmpty == false
        else {
            return nil
        }

        let keyCode = Int(object.value(forKey: "\(prefix)KeyCode") as? Int64 ?? 0)
        let modifiers = decodeModifiers(object.value(forKey: "\(prefix)ModifiersBlob") as? Data)
        let displayLabel = object.value(forKey: "\(prefix)DisplayLabel") as? String
        return HotkeyDescriptor(
            keyCode: keyCode,
            keyEquivalent: keyEquivalent,
            modifiers: modifiers,
            displayLabel: displayLabel
        )
    }

    private func encodeModifiers(_ modifiers: [HotkeyModifier]) -> Data? {
        let rawValues = modifiers.map(\.rawValue)
        return try? encoder.encode(rawValues)
    }

    private func decodeModifiers(_ data: Data?) -> [HotkeyModifier] {
        guard
            let data,
            let rawValues = try? decoder.decode([String].self, from: data)
        else {
            return []
        }

        return rawValues.compactMap(HotkeyModifier.init(rawValue:))
    }

    private static func makeManagedObjectModel(named name: String) -> NSManagedObjectModel {
        if let modelURL = Bundle.main.url(forResource: name, withExtension: "momd"),
           let model = NSManagedObjectModel(contentsOf: modelURL) {
            return model
        }

        let model = NSManagedObjectModel()
        model.entities = [
            makeSnippetEntity(),
            makeGlobalBindingEntity()
        ]
        return model
    }

    private static func makeSnippetEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = snippetEntityName
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            makeAttribute(name: "id", type: .stringAttributeType),
            makeAttribute(name: "title", type: .stringAttributeType),
            makeAttribute(name: "content", type: .stringAttributeType),
            makeAttribute(name: "kindRawValue", type: .stringAttributeType),
            makeAttribute(name: "createdAt", type: .dateAttributeType),
            makeAttribute(name: "updatedAt", type: .dateAttributeType),
            makeAttribute(name: "isPinned", type: .booleanAttributeType, optional: false, defaultValue: false),
            makeAttribute(name: "hotkeyKeyCode", type: .integer64AttributeType, optional: true),
            makeAttribute(name: "hotkeyKeyEquivalent", type: .stringAttributeType, optional: true),
            makeAttribute(name: "hotkeyDisplayLabel", type: .stringAttributeType, optional: true),
            makeAttribute(name: "hotkeyModifiersBlob", type: .binaryDataAttributeType, optional: true)
        ]
        return entity
    }

    private static func makeGlobalBindingEntity() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = globalBindingEntityName
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = [
            makeAttribute(name: "commandIDRawValue", type: .stringAttributeType),
            makeAttribute(name: "availabilityRawValue", type: .stringAttributeType, optional: false, defaultValue: HotkeyRuntimeAvailability.enabled.rawValue),
            makeAttribute(name: "detailText", type: .stringAttributeType, optional: true),
            makeAttribute(name: "hotkeyKeyCode", type: .integer64AttributeType, optional: true),
            makeAttribute(name: "hotkeyKeyEquivalent", type: .stringAttributeType, optional: true),
            makeAttribute(name: "hotkeyDisplayLabel", type: .stringAttributeType, optional: true),
            makeAttribute(name: "hotkeyModifiersBlob", type: .binaryDataAttributeType, optional: true)
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

    private static let snippetEntityName = "SnippetRecordEntity"
    private static let globalBindingEntityName = "GlobalHotkeyBindingEntity"
}

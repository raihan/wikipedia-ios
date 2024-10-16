import XCTest
@testable import WMFData
import CoreData

final class WMFCoreDataStoreTests: XCTestCase {
    
    enum WMFCoreDataStoreTestsError: Error {
        case empty
    }
    
    lazy var store: WMFCoreDataStore = {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return try! WMFCoreDataStore(appContainerURL: temporaryDirectory)
    }()
    
    override func setUp() async throws {
        _ = self.store
        // Wait for store to load asyncronously
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    func testCreateAndFetch() throws {
        
        // First save new record
        let backgroundContext = try store.newBackgroundContext
        let page = try store.create(entityType: CDPage.self, entityName: "CDPage", in: backgroundContext)
        page.title = "Cat"
        page.namespaceID = 0
        page.projectID = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil)).coreDataIdentifier
        page.timestamp = Date()
        
        try store.saveIfNeeded(moc: backgroundContext)

        // Then pull from store, confirm values match
        guard let pulledPage = try store.fetch(entityType: CDPage.self, entityName: "CDPage", predicate: nil, fetchLimit: 1, in: backgroundContext)?.first else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(pulledPage.title, "Cat")
        XCTAssertEqual(pulledPage.namespaceID, 0)
        XCTAssertEqual(pulledPage.projectID, "wikipedia~en")
        XCTAssertNotNil(pulledPage.timestamp)
    }
    
    func testFetchOrCreate() throws {
        
        // First confirm no items in store
        let predicate = NSPredicate(format: "projectID == %@ && namespaceID == %@ && title == %@", argumentArray: ["wikipedia~en", 0, "Dog"])
        
        let backgroundContext = try store.newBackgroundContext
        guard let initialPages = try store.fetch(entityType: CDPage.self, entityName: "CDPage", predicate: predicate, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(initialPages.count, 0)
        
        // Then fetch or create
        guard let savedPage = try store.fetchOrCreate(entityType: CDPage.self, entityName: "CDPage", predicate: predicate, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }

        savedPage.title = "Dog"
        savedPage.namespaceID = 0
        savedPage.projectID = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil)).coreDataIdentifier
        savedPage.timestamp = Date()
        
        try store.saveIfNeeded(moc: backgroundContext)

        // Then pull from store again, confirm only one page saved
        guard let nextPages = try store.fetch(entityType: CDPage.self, entityName: "CDPage", predicate: predicate, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(nextPages.count, 1)
        
        // Try saving again, confirm we don't add a duplicate
        guard let anotherSavedPage = try store.fetchOrCreate(entityType: CDPage.self, entityName: "CDPage", predicate: predicate, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }

        anotherSavedPage.title = "Dog"
        anotherSavedPage.namespaceID = 0
        anotherSavedPage.projectID = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil)).coreDataIdentifier
        anotherSavedPage.timestamp = Date()
        
        try store.saveIfNeeded(moc: backgroundContext)
        
        // Then pull from store once more, confirm still only one page saved
        guard let finalPages = try store.fetch(entityType: CDPage.self, entityName: "CDPage", predicate: predicate, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(finalPages.count, 1)
    }
    
    func testFetchGrouped() throws {
        
        // First save new records
        let backgroundContext = try store.newBackgroundContext
        let page = try store.create(entityType: CDPage.self, entityName: "CDPage", in: backgroundContext)
        page.title = "Cat"
        page.namespaceID = 0
        page.projectID = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil)).coreDataIdentifier
        page.timestamp = Date()
        
        let pageView1 = try store.create(entityType: CDPageView.self, entityName: "CDPageView", in: backgroundContext)
        pageView1.timestamp = Date.init(timeIntervalSinceNow: -(60*60))
        pageView1.page = page
        
        let pageView2 = try store.create(entityType: CDPageView.self, entityName: "CDPageView", in: backgroundContext)
        pageView2.timestamp = Date()
        pageView2.page = page
        
        try store.saveIfNeeded(moc: backgroundContext)
        
        // Then fetch grouped and compare counts
        let pageViews = try store.fetchGrouped(entityName: "CDPageView", predicate: nil, propertyToCount: "page", propertiesToGroupBy: ["page"], propertiesToFetch: ["page"], in: backgroundContext)
        XCTAssertEqual(pageViews.count, 1)
        let pageViewsDict = pageViews[0]
        XCTAssertEqual(pageViewsDict["page"] as? NSManagedObjectID, page.objectID)
        XCTAssertEqual(pageViewsDict["count"] as? Int, 2)
    }
    
    func testDatabaseHousekeeping() async throws {
        
        let overTwoYearsAgoInSeconds = TimeInterval(60 * 60 * 24 * 800)
        
        // First save new records
        let backgroundContext = try store.newBackgroundContext
        let catPage = try store.create(entityType: CDPage.self, entityName: "CDPage", in: backgroundContext)
        catPage.title = "Cat"
        catPage.namespaceID = 0
        catPage.projectID = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil)).coreDataIdentifier
        catPage.timestamp = Date(timeIntervalSinceNow: -(60*60))
        
        let catPageView1 = try store.create(entityType: CDPageView.self, entityName: "CDPageView", in: backgroundContext)
        catPageView1.timestamp = Date(timeIntervalSinceNow: -(60*60))
        catPageView1.page = catPage
        
        let catPageView2 = try store.create(entityType: CDPageView.self, entityName: "CDPageView", in: backgroundContext)
        catPageView2.timestamp = Date()
        catPageView2.page = catPage
        
        let dogPage = try store.create(entityType: CDPage.self, entityName: "CDPage", in: backgroundContext)
        dogPage.title = "Dog"
        dogPage.namespaceID = 0
        dogPage.projectID = WMFProject.wikipedia(WMFLanguage(languageCode: "en", languageVariantCode: nil)).coreDataIdentifier
        dogPage.timestamp = Date(timeIntervalSinceNow: -(overTwoYearsAgoInSeconds + 20))
        
        let dogPageView1 = try store.create(entityType: CDPageView.self, entityName: "CDPageView", in: backgroundContext)
        dogPageView1.timestamp = Date(timeIntervalSinceNow: -(overTwoYearsAgoInSeconds + 20))
        dogPageView1.page = dogPage
        
        let dogPageView2 = try store.create(entityType: CDPageView.self, entityName: "CDPageView", in: backgroundContext)
        dogPageView2.timestamp = Date(timeIntervalSinceNow: -(overTwoYearsAgoInSeconds))
        dogPageView2.page = dogPage
        
        try store.saveIfNeeded(moc: backgroundContext)
        
        // Confirm counts
        guard let pages = try store.fetch(entityType: CDPage.self, entityName: "CDPage", predicate: nil, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(pages.count, 2)
        
        guard let pageViews = try store.fetch(entityType: CDPageView.self, entityName: "CDPageView", predicate: nil, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(pageViews.count, 4)
        
        // Clean up via database housekeeper
        try await store.performDatabaseHousekeeping()
        
        backgroundContext.refreshAllObjects()
        
        guard let newPages = try store.fetch(entityType: CDPage.self, entityName: "CDPage", predicate: nil, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(newPages.count, 1)
        
        guard let newPageViews = try store.fetch(entityType: CDPageView.self, entityName: "CDPageView", predicate: nil, fetchLimit: nil, in: backgroundContext) else {
            throw WMFCoreDataStoreTestsError.empty
        }
        
        XCTAssertEqual(newPageViews.count, 2)
    }
}

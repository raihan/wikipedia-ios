import XCTest
@testable import WMFData
@testable import WMFDataMocks
import CoreData

final class YearInReviewDataControllerTests: XCTestCase {

    lazy var store: WMFCoreDataStore = {
        let temporaryDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return try! WMFCoreDataStore(appContainerURL: temporaryDirectory)
    }()

    lazy var dataController: WMFYearInReviewDataController = {
        let dataController = try! WMFYearInReviewDataController(coreDataStore: store)
        return dataController
    }()
    
    private var enProject: WMFProject {
        let language = WMFLanguage(languageCode: "en", languageVariantCode: nil)
        return WMFProject.wikipedia(language)
    }
    
    private var usCountryCode: String? {
        return Locale(identifier: "en_US").region?.identifier
    }
    
    private var frCountryCode: String? {
        return Locale(identifier: "fr_FR").region?.identifier
    }
    
    private var frProject: WMFProject {
        let language = WMFLanguage(languageCode: "fr", languageVariantCode: nil)
        return WMFProject.wikipedia(language)
    }

    override func setUp() async throws {
        _ = self.store
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }

    func testCreateNewYearInReviewReport() async throws {
        let slide1 = WMFYearInReviewSlide(year: 2024, id: .editCount,  evaluated: true, display: true, data: nil)
        let slide2 = WMFYearInReviewSlide(year: 2023, id: .readCount, evaluated: false, display: true, data: nil)

        try await dataController.createNewYearInReviewReport(year: 2023, slides: [slide1, slide2])

        let reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)
        XCTAssertEqual(reports!.count, 1)
        XCTAssertEqual(reports![0].year, 2023)
        XCTAssertEqual(reports![0].slides!.count, 2)
    }

    func testSaveYearInReviewReport() async throws {
        let slide = WMFYearInReviewSlide(year: 2024, id: .editCount,  evaluated: true, display: true, data: nil)
        let report = WMFYearInReviewReport(year: 2024, slides: [slide])

        try await dataController.saveYearInReviewReport(report)

        let reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)

        XCTAssertEqual(reports!.count, 1)
        XCTAssertEqual(reports![0].year, 2024)
        XCTAssertEqual(reports![0].slides!.count, 1)
    }

    func testFetchYearInReviewReports() async throws {
        let slide = WMFYearInReviewSlide(year: 2024, id: .editCount,  evaluated: true, display: true, data: nil)
        let slide2 = WMFYearInReviewSlide(year: 2024, id: .readCount,  evaluated: true, display: true, data: nil)
        let report = WMFYearInReviewReport(year: 2024, slides: [slide, slide2])

        try await dataController.saveYearInReviewReport(report)

        let reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)
        XCTAssertEqual(reports!.count, 1)
        XCTAssertEqual(reports![0].year, 2024)
        XCTAssertEqual(reports![0].slides!.count, 2)
    }

    func testFetchYearInReviewReportForYear() async throws {
        let slide1 = WMFYearInReviewSlide(year: 2021, id: .editCount, evaluated: true, display: true)
        let slide2 = WMFYearInReviewSlide(year: 2021, id: .readCount, evaluated: false, display: true)

        let report = WMFYearInReviewReport(year: 2021, slides: [slide1, slide2])
        try await dataController.saveYearInReviewReport(report)

        let fetchedReport = try await dataController.fetchYearInReviewReport(forYear: 2021)

        XCTAssertNotNil(fetchedReport, "Expected to fetch a report for year 2021")

        XCTAssertEqual(fetchedReport?.year, 2021)
        XCTAssertEqual(fetchedReport?.slides.count, 2)

        let fetchedSlideIDs = fetchedReport?.slides.map { $0.id }.sorted()
        let originalSlideIDs = [slide1.id, slide2.id].sorted()
        XCTAssertEqual(fetchedSlideIDs, originalSlideIDs)

        let noReport = try await dataController.fetchYearInReviewReport(forYear: 2020)
        XCTAssertNil(noReport, "Expected no report for year 2020")
    }

    func testDeleteYearInReviewReport() async throws {
        let slide = WMFYearInReviewSlide(year: 2021, id: .readCount,  evaluated: true, display: true, data: nil)
        try await dataController.createNewYearInReviewReport(year: 2021, slides: [slide])

        var reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)
        XCTAssertEqual(reports!.count, 1)

        try await dataController.deleteYearInReviewReport(year: 2021)

        reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)
        XCTAssertEqual(reports!.count, 0)
    }

    func testDeleteAllYearInReviewReports() async throws {
        let slide1 = WMFYearInReviewSlide(year: 2024, id: .editCount,  evaluated: true, display: true, data: nil)
        let slide2 = WMFYearInReviewSlide(year: 2023, id: .readCount, evaluated: false, display: true, data: nil)

        try await dataController.createNewYearInReviewReport(year: 2024, slides: [slide1])
        try await dataController.createNewYearInReviewReport(year: 2023, slides: [slide2])

        var reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)
        XCTAssertEqual(reports!.count, 1)

        try await dataController.deleteAllYearInReviewReports()

        reports = try store.fetch(entityType: CDYearInReviewReport.self, entityName: "CDYearInReviewReport", predicate: nil, fetchLimit: 1, in: store.viewContext)
        XCTAssertEqual(reports!.count, 0)
    }
    
    func testYearInReviewEntryPointFeatureDisabled() throws {
        
        // Create mock developer settings config
        let readCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
        let editCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
        let personalizedSlides = WMFFeatureConfigResponse.IOS.YearInReview.PersonalizedSlides(readCount: readCountSlideSettings, editCount: editCountSlideSettings)
        let yearInReview = WMFFeatureConfigResponse.IOS.YearInReview(isEnabled: false, countryCodes: ["FR", "IT"], primaryAppLanguageCodes: ["fr", "it"], dataPopulationStartDateString: "2024-01-01T00:00:00Z", dataPopulationEndDateString: "2024-11-01T00:00:00Z", personalizedSlides: personalizedSlides)
        let ios = WMFFeatureConfigResponse.IOS(version: 1, yir: yearInReview)
        let config = WMFFeatureConfigResponse(ios: [ios])
        
        // Create mock developer settings data controller
        let developerSettingsDataController = WMFMockDeveloperSettingsDataController(featureConfig: config)
        
        // Create year in review data controller to test
        let yearInReviewDataController = try WMFYearInReviewDataController(coreDataStore: store, developerSettingsDataController: developerSettingsDataController)
        
        guard let frCountryCode else {
            XCTFail("Missing expected country codes")
            return
        }
        
        let shouldShowEntryPoint = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: frCountryCode, primaryAppLanguageProject: frProject)
        
        XCTAssertFalse(shouldShowEntryPoint, "FR should not show entry point for mock config of with disabled YiR feature.")
    }
    
    func testYearInReviewEntryPointCountryCode() throws {
        
        // Create mock developer settings config
        let readCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
        let editCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
        let personalizedSlides = WMFFeatureConfigResponse.IOS.YearInReview.PersonalizedSlides(readCount: readCountSlideSettings, editCount: editCountSlideSettings)
        let yearInReview = WMFFeatureConfigResponse.IOS.YearInReview(isEnabled: true, countryCodes: ["FR", "IT"], primaryAppLanguageCodes: ["fr", "it"], dataPopulationStartDateString: "2024-01-01T00:00:00Z", dataPopulationEndDateString: "2024-11-01T00:00:00Z", personalizedSlides: personalizedSlides)
        let ios = WMFFeatureConfigResponse.IOS(version: 1, yir: yearInReview)
        let config = WMFFeatureConfigResponse(ios: [ios])
        
        // Create mock developer settings data controller
        let developerSettingsDataController = WMFMockDeveloperSettingsDataController(featureConfig: config)
        
        // Create year in review data controller to test
        let yearInReviewDataController = try WMFYearInReviewDataController(coreDataStore: store, developerSettingsDataController: developerSettingsDataController)
        
        guard let usCountryCode, let frCountryCode else {
            XCTFail("Missing expected country codes")
            return
        }
        
        let shouldShowEntryPointUS = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: usCountryCode, primaryAppLanguageProject: frProject)
        
        XCTAssertFalse(shouldShowEntryPointUS, "US should not show entry point for mock YiR config of [FR, IT] country codes.")

        let shouldShowEntryPointFR = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: frCountryCode, primaryAppLanguageProject: frProject)
        
        XCTAssertTrue(shouldShowEntryPointFR, "FR should show entry point for mock YiR config of [FR, IT] country codes.")
    }
    
    func testYearInReviewEntryPointPrimaryAppLanguageProject() throws {
        
        // Create mock developer settings config
        let readCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
        let editCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
        let personalizedSlides = WMFFeatureConfigResponse.IOS.YearInReview.PersonalizedSlides(readCount: readCountSlideSettings, editCount: editCountSlideSettings)
        let yearInReview = WMFFeatureConfigResponse.IOS.YearInReview(isEnabled: true, countryCodes: ["FR", "IT"], primaryAppLanguageCodes: ["fr", "it"], dataPopulationStartDateString: "2024-01-01T00:00:00Z", dataPopulationEndDateString: "2024-11-01T00:00:00Z", personalizedSlides: personalizedSlides)
        let ios = WMFFeatureConfigResponse.IOS(version: 1, yir: yearInReview)
        let config = WMFFeatureConfigResponse(ios: [ios])
        
        // Create mock developer settings data controller
        let developerSettingsDataController = WMFMockDeveloperSettingsDataController(featureConfig: config)
        
        // Create year in review data controller to test
        let yearInReviewDataController = try WMFYearInReviewDataController(coreDataStore: store, developerSettingsDataController: developerSettingsDataController)
        
        guard let frCountryCode else {
            XCTFail("Missing expected country codes")
            return
        }
        
        let shouldShowEntryPointENProject = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: frCountryCode, primaryAppLanguageProject: enProject)
        
        XCTAssertFalse(shouldShowEntryPointENProject, "Primary app language EN project should not show entry point for mock YiR config of [FR, IT] primary app language projects.")

        let shouldShowEntryPointFRProject = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: frCountryCode, primaryAppLanguageProject: frProject)
        
        XCTAssertTrue(shouldShowEntryPointFRProject, "Primary app language FR project should show entry point for mock YiR config of [FR, IT] primary app language projects.")
    }
    
    // TODO: Bring back once at least one personalized slide is in: T376066 or T376320
   
//    func testYearInReviewEntryPointDisabledPersonalizedSlides() {
//
//        // Create mock developer settings config
//        let readCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: false)
//        let editCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: false)
//        let personalizedSlides = WMFFeatureConfigResponse.IOS.YearInReview.PersonalizedSlides(readCount: readCountSlideSettings, editCount: editCountSlideSettings)
//        let yearInReview = WMFFeatureConfigResponse.IOS.YearInReview(isEnabled: true, countryCodes: ["FR", "IT"], primaryAppLanguageCodes: ["fr", "it"], dataPopulationStartDateString: "2024-01-01T00:00:00Z", dataPopulationEndDateString: "2024-11-01T00:00:00Z", personalizedSlides: personalizedSlides)
//        let ios = WMFFeatureConfigResponse.IOS(version: 1, yir: yearInReview)
//        let config = WMFFeatureConfigResponse(ios: [ios])
//
//        // Create mock developer settings data controller
//        let developerSettingsDataController = WMFMockDeveloperSettingsDataController(featureConfig: config)
//
//        // Create year in review data controller to test
//        let yearInReviewDataController = WMFYearInReviewDataController(developerSettingsDataController: developerSettingsDataController)
//
//        guard let frCountryCode else {
//            XCTFail("Missing expected country codes")
//            return
//        }
//
//        let shouldShowEntryPoint = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: frCountryCode, primaryAppLanguageProject: frProject)
//
//        XCTAssertFalse(shouldShowEntryPoint, "Should not show entry point when both personalized slides are disabled.")
//    }
//
//    func testYearInReviewEntryPointOneEnabledPersonalizedSlide() {
//
//        // Create mock developer settings config
//        let readCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: true)
//        let editCountSlideSettings = WMFFeatureConfigResponse.IOS.YearInReview.SlideSettings(isEnabled: false)
//        let personalizedSlides = WMFFeatureConfigResponse.IOS.YearInReview.PersonalizedSlides(readCount: readCountSlideSettings, editCount: editCountSlideSettings)
//        let yearInReview = WMFFeatureConfigResponse.IOS.YearInReview(isEnabled: true, countryCodes: ["FR", "IT"], primaryAppLanguageCodes: ["fr", "it"], dataPopulationStartDateString: "2024-01-01T00:00:00Z", dataPopulationEndDateString: "2024-11-01T00:00:00Z", personalizedSlides: personalizedSlides)
//        let ios = WMFFeatureConfigResponse.IOS(version: 1, yir: yearInReview)
//        let config = WMFFeatureConfigResponse(ios: [ios])
//
//        // Create mock developer settings data controller
//        let developerSettingsDataController = WMFMockDeveloperSettingsDataController(featureConfig: config)
//
//        // Create year in review data controller to test
//        let yearInReviewDataController = WMFYearInReviewDataController(developerSettingsDataController: developerSettingsDataController)
//
//        guard let frCountryCode else {
//            XCTFail("Missing expected country codes")
//            return
//        }
//
//        let shouldShowEntryPoint = yearInReviewDataController.shouldShowYearInReviewEntryPoint(countryCode: frCountryCode, primaryAppLanguageProject: frProject)
//
//        XCTAssertTrue(shouldShowEntryPoint, "Should show entry point when one personalized slide is enabled.")
//    }
}

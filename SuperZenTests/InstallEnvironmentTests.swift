import Foundation
import Testing

@testable import SuperZen

@MainActor
private final class FakeLoginItem: LoginItemService {
  struct Refused: Error {}

  var isEnabled: Bool
  var registerFails = false
  private(set) var registerCalls = 0
  private(set) var unregisterCalls = 0

  init(isEnabled: Bool = false) {
    self.isEnabled = isEnabled
  }

  func register() throws {
    registerCalls += 1
    if registerFails { throw Refused() }
    isEnabled = true
  }

  func unregister() throws {
    unregisterCalls += 1
    isEnabled = false
  }
}

@MainActor
struct InstallEnvironmentTests {
  private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  @Test func processIDsThatWrappedStillOrderByLaunchDate() {
    let running = SingleInstance.Instance(processID: 99_990, launchDate: start)
    let own = SingleInstance.Instance(processID: 120, launchDate: start.addingTimeInterval(3600))
    #expect(SingleInstance.olderInstances(than: own, in: [running, own]) == [running])
    #expect(SingleInstance.olderInstances(than: running, in: [running, own]).isEmpty)
  }

  @Test func exactlyOneOfTwoSimultaneousLaunchesSurvives() {
    let first = SingleInstance.Instance(processID: 500, launchDate: start)
    let second = SingleInstance.Instance(processID: 501, launchDate: start)
    let all = [first, second]
    #expect(SingleInstance.olderInstances(than: second, in: all) == [first])
    #expect(SingleInstance.olderInstances(than: first, in: all).isEmpty)
  }

  @Test func missingLaunchDatesFallBackToProcessOrder() {
    let first = SingleInstance.Instance(processID: 500, launchDate: nil)
    let second = SingleInstance.Instance(processID: 501, launchDate: start)
    #expect(SingleInstance.olderInstances(than: second, in: [first, second]) == [first])
    #expect(SingleInstance.olderInstances(than: first, in: [first, second]).isEmpty)
  }

  @Test func ownProcessIsNeverItsOwnPredecessor() {
    let own = SingleInstance.Instance(processID: 7, launchDate: start)
    #expect(SingleInstance.olderInstances(than: own, in: [own]).isEmpty)
  }

  @Test func kernelStartTimeIdentifiesTheOlderOfTwoRealProcesses() throws {
    let own = ProcessInfo.processInfo.processIdentifier
    let ownStart = try #require(SingleInstance.startDate(ofProcess: own))
    #expect(ownStart < Date())

    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sleep")
    child.arguments = ["30"]
    try child.run()
    defer { child.terminate() }

    let childInstance = SingleInstance.instance(processID: child.processIdentifier)
    #expect(childInstance.launchDate != nil)
    let ownInstance = SingleInstance.instance(processID: own)
    #expect(SingleInstance.olderInstances(than: childInstance, in: [ownInstance, childInstance]) == [ownInstance])
    #expect(SingleInstance.olderInstances(than: ownInstance, in: [ownInstance, childInstance]).isEmpty)
  }

  @Test func exitedProcessHasNoStartDate() throws {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    try child.run()
    child.waitUntilExit()
    #expect(SingleInstance.startDate(ofProcess: child.processIdentifier) == nil)
  }

  @Test func translocatedDownloadIsRecognised() {
    let url = URL(fileURLWithPath: "/private/var/folders/ab/xyz/T/AppTranslocation/6F2E/d/SuperZen.app")
    #expect(InstallLocation.classify(bundleURL: url, isReadOnlyVolume: { _ in true }) == .translocated)
  }

  @Test func mountedDiskImageIsReadOnly() {
    let url = URL(fileURLWithPath: "/Volumes/SuperZen 2.0/SuperZen.app")
    #expect(InstallLocation.classify(bundleURL: url, isReadOnlyVolume: { _ in true }) == .readOnlyVolume)
  }

  @Test func applicationsFolderAndUnusualPathsAreSupported() {
    for path in ["/Applications/SuperZen.app", "/Users/zoë/Mis Aplicaciones/SuperZen.app"] {
      let url = URL(fileURLWithPath: path)
      #expect(InstallLocation.classify(bundleURL: url, isReadOnlyVolume: { _ in false }) == .supported)
    }
  }

  @Test func runningBundleLocationIsClassifiedWithoutTrapping() {
    _ = InstallLocation.current
  }

  @Test func explanationExistsOnlyWhenLaunchAtLoginIsBlocked() {
    #expect(InstallLocation.supported.launchAtLoginExplanation == nil)
    #expect(InstallLocation.translocated.launchAtLoginExplanation?.isEmpty == false)
    #expect(InstallLocation.readOnlyVolume.launchAtLoginExplanation?.isEmpty == false)
  }

  @Test func launchAtLoginIsRefusedFromATranslocatedCopy() {
    let service = FakeLoginItem()
    let manager = LaunchManager(service: service, location: { .translocated })
    #expect(manager.setLaunchAtLogin(true) == false)
    #expect(service.registerCalls == 0)
    #expect(manager.unavailableReason != nil)
  }

  @Test func launchAtLoginRegistersFromAnInstalledCopy() {
    let service = FakeLoginItem()
    let manager = LaunchManager(service: service, location: { .supported })
    #expect(manager.setLaunchAtLogin(true))
    #expect(service.registerCalls == 1)
    #expect(manager.setLaunchAtLogin(true))
    #expect(service.registerCalls == 1)
    #expect(manager.unavailableReason == nil)
  }

  @Test func failedRegistrationReportsTheRealStateInsteadOfThrowing() {
    let service = FakeLoginItem()
    service.registerFails = true
    let manager = LaunchManager(service: service, location: { .supported })
    #expect(manager.setLaunchAtLogin(true) == false)
    #expect(service.registerCalls == 1)
  }

  @Test func launchAtLoginCanStillBeSwitchedOffFromAnyLocation() {
    let service = FakeLoginItem(isEnabled: true)
    let manager = LaunchManager(service: service, location: { .readOnlyVolume })
    #expect(manager.setLaunchAtLogin(false) == false)
    #expect(service.unregisterCalls == 1)
  }
}

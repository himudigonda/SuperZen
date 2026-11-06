public enum BreakPresentation: String, CaseIterable, Sendable {
  case fullScreen
  case banner

  public init(setting: String?) {
    self = setting.flatMap(BreakPresentation.init(rawValue:)) ?? .fullScreen
  }

  public func effective(for difficulty: BreakDifficulty) -> BreakPresentation {
    difficulty == .hardcore ? .fullScreen : self
  }

  public func issue(for difficulty: BreakDifficulty) -> SettingsIssue? {
    self == .banner && difficulty == .hardcore ? .bannerUnavailableInHardcore : nil
  }
}

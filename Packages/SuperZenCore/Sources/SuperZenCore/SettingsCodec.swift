import Foundation

public enum SettingsCodec {
  public static func encode(_ settings: Settings) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(settings)
  }

  public static func decode(_ data: Data) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: data).validated()
  }
}

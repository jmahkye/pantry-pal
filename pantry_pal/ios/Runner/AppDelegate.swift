import Flutter
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

private let channelName = "com.jmak.pantry_pal/recipes"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "RecipeChannel") {
      RecipeChannel.register(messenger: registrar.messenger())
    }
  }
}

// MARK: - Recipe MethodChannel bridge

enum RecipeChannel {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(Self.isAvailable())
      case "generate":
        guard
          let args = call.arguments as? [String: Any],
          let pantry = args["pantry"] as? [[String: Any]]
        else {
          result(FlutterError(code: "bad_args", message: "Missing pantry", details: nil))
          return
        }
        let maxResults = (args["maxResults"] as? Int) ?? 5
        Task {
          do {
            let json = try await Self.generate(pantry: pantry, maxResults: maxResults)
            result(json)
          } catch {
            result(FlutterError(code: "generate_failed",
                                message: error.localizedDescription, details: nil))
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func isAvailable() -> Bool {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      if case .available = SystemLanguageModel.default.availability { return true }
    }
    #endif
    return false
  }

  private static func generate(pantry: [[String: Any]], maxResults: Int) async throws -> String {
    #if canImport(FoundationModels)
    if #available(iOS 26.0, *) {
      return try await FoundationModelsRecipeBackend.generate(pantry: pantry, maxResults: maxResults)
    }
    #endif
    throw NSError(domain: "RecipeChannel", code: -1,
                  userInfo: [NSLocalizedDescriptionKey: "Foundation Models not available on this device"])
  }
}

#if canImport(FoundationModels)

@available(iOS 26.0, *)
@Generable
struct GeneratedRecipe {
  @Guide(description: "Short, appetising title (3 to 6 words).")
  let title: String

  @Guide(description: "One-sentence summary of the dish.")
  let summary: String

  @Guide(description: "Names of pantry ingredients used. No quantities, no items outside the pantry list.")
  let ingredients: [String]

  @Guide(description: "Cooking steps in order, each a single short sentence.")
  let steps: [String]

  @Guide(description: "Approximate total prep plus cook time in minutes.")
  let prepMinutes: Int
}

@available(iOS 26.0, *)
@Generable
struct GeneratedRecipeList {
  @Guide(description: "Suggested recipes using only what is in the pantry.")
  let recipes: [GeneratedRecipe]
}

@available(iOS 26.0, *)
enum FoundationModelsRecipeBackend {
  static func generate(pantry: [[String: Any]], maxResults: Int) async throws -> String {
    let pantryDescription = pantry.compactMap(describe).joined(separator: "\n")

    let instructions = """
      You are a helpful cooking assistant. Suggest realistic recipes that use only ingredients \
      from the user's pantry. Prefer ingredients that are expiring soonest. Keep instructions \
      practical and concise. Do not invent ingredients that are not in the pantry list.
      """

    let session = LanguageModelSession(instructions: instructions)
    let prompt = """
      Pantry:
      \(pantryDescription)

      Suggest up to \(maxResults) recipes.
      """

    let response = try await session.respond(
      to: prompt,
      generating: GeneratedRecipeList.self
    )

    let payload = response.content.recipes.map { recipe in
      [
        "title": recipe.title,
        "summary": recipe.summary,
        "ingredients": recipe.ingredients,
        "steps": recipe.steps,
        "prepMinutes": recipe.prepMinutes,
      ] as [String: Any]
    }
    let data = try JSONSerialization.data(withJSONObject: ["recipes": payload])
    return String(data: data, encoding: .utf8) ?? "{\"recipes\":[]}"
  }

  private static func describe(_ item: [String: Any]) -> String? {
    guard let name = item["name"] as? String else { return nil }
    var parts: [String] = [name]
    if let qty = item["quantity"], let unit = item["unit"] as? String {
      parts.append("(\(qty)\(unit))")
    }
    if let category = item["category"] as? String {
      parts.append("[\(category)]")
    }
    if let expiry = item["expiryDate"] as? String {
      parts.append("expires \(expiry)")
    }
    return "- " + parts.joined(separator: " ")
  }
}

#endif

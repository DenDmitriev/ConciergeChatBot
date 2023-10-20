import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor
import TelegramVaporBot

let TGBOT: TGBotConnection = .init()
let RUNTYPE: RunType = .prod
let TGBOTNAME = "@ConciergeChatBot"

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // MARK: - Database configure
    let databaseFile = "db.sqlite"
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file(databaseFile)), as: .sqlite)
    let databasePath = DatabaseService.createPath(for: RUNTYPE, file: databaseFile, app: app)
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file(databasePath)), as: .sqlite)

    // Migration
    app.migrations.add(CreateHouse())
    app.migrations.add(CreateResident())
    app.migrations.add(CreateCar())
    app.migrations.add(CreateBlockedCar())
    try await app.autoMigrate()
    
    print("💽 Database exists on path", databasePath, FileManager.default.fileExists(atPath: databasePath))
    
    // MARK: - TelegramVaporBot configure
    guard let apiKeys = Config.parse() else { return }
    let tgApi = apiKeys.telegramApiKey
    print("🔐 Telegram API key gated")
    
    // set level of debug if you needed
    TGBot.log.logLevel = app.logger.logLevel
    let bot: TGBot = .init(app: app, botId: tgApi)
    await TGBOT.setConnection(try await TGLongPollingConnection(bot: bot))
    
    // MARK: - Register handlers
    await DefaultBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await RegistrationHouseBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await SignResidentsBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    await PrivateBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await CarBotHandler.addHandlers(app: app, connection: TGBOT.connection)
    await NeighborBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    await AdminBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    
    // MARK: - Start
    try await TGBOT.connection.start()

    // MARK: - Register routes
    try routes(app)
}

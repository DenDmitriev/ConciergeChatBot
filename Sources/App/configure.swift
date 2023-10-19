import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor
import TelegramVaporBot

let TGBOT: TGBotConnection = .init()

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(DatabaseConfigurationFactory.sqlite(.file("db.sqlite")), as: .sqlite)
    
    let runType: RunType = .prod
    
    // MARK: - Database configure
    if let workingDirectory = URL(string: app.directory.workingDirectory) {
        let dataDirectory = workingDirectory.appendingPathComponent("data")
        if !FileManager.default.fileExists(atPath: dataDirectory.path) {
            do {
                try FileManager.default.createDirectory(atPath: dataDirectory.path, withIntermediateDirectories: true)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    let databasePath: String = {
        switch runType {
        case .dev:
            return app.directory.workingDirectory + "data/db.sqlite"
        case .prod:
            return "/data/db.sqlite"
        }
    }()
    print("💽 Database exists on path", databasePath, FileManager.default.fileExists(atPath: databasePath))
    app.databases.use(DatabaseConfigurationFactory.sqlite(.file(databasePath)), as: .sqlite)

    app.migrations.add(CreateHouse())
    app.migrations.add(CreateResident())
    app.migrations.add(CreateCar())
    app.migrations.add(CreateBlockedCar())
    try await app.autoMigrate()
    
    // MARK: - TelegramVaporBot configure
     guard let tgApi = ApiKeys.decode()?.telegramApiKey else { return }
    print("🔐 Telegram API key gated")
//    let tgApi = "1416179872:AAH8OMUniQk3QY5qUT2EoT9hEHP09LKUXrQ"
    // set level of debug if you needed
    TGBot.log.logLevel = app.logger.logLevel
    let bot: TGBot = .init(app: app, botId: tgApi)
    await TGBOT.setConnection(try await TGLongPollingConnection(bot: bot))
    
//    await TestBotsHadlers.addHandlers(app: app, connection: TGBOT.connection)
    await DefaultBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await RegistrationHouseBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await SignResidentsBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    await PrivateBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    try await CarBotHandler.addHandlers(app: app, connection: TGBOT.connection)
    await NeighborBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    await AdminBotHandlers.addHandlers(app: app, connection: TGBOT.connection)
    
    try await TGBOT.connection.start()

    // MARK: - Register routes
    try routes(app)
}

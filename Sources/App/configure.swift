import NIOSSL
import Fluent
import FluentMySQLDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

   // 2
    app.databases.use(.mysql(
      hostname: Environment.get("DATABASE_HOST") ?? "localhost",
      username: Environment.get("DATABASE_USERNAME")
        ?? "vapor_username",
      password: Environment.get("DATABASE_PASSWORD")
        ?? "vapor_password",
      database: Environment.get("DATABASE_NAME")
        ?? "vapor_database",
      tlsConfiguration: .forClient(certificateVerification: .none)
    ), as: .mysql) 
   // 1
  app.migrations.add(CreateAcronym())
    
  // 2
  app.logger.logLevel = .debug

  // 3
  try app.autoMigrate().wait()
    
    // register routes
    try routes(app)
}

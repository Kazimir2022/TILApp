import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

// configures your application
public func configure(_ app: Application)  throws {
  // uncomment to serve files from /Public folder
  // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
  let databaseName: String
  let databasePort: Int
  // 1 В зависимости от среды устанавливаем имя базы данных и номер порта
  if (app.environment == .testing) {
    databaseName = "vapor-test"
    databasePort = 5433
  } else {
    databaseName = "vapor_database"
    databasePort = 5432
  }
  
  app.databases.use(.postgres(
    hostname: Environment.get("DATABASE_HOST")
    ?? "localhost",
    port: databasePort,
    username: Environment.get("DATABASE_USERNAME")
    ?? "vapor_username",
    password: Environment.get("DATABASE_PASSWORD")
    ?? "vapor_password",
    database: Environment.get("DATABASE_NAME")
    ?? databaseName
  ), as: .psql)
  
  // 1 Добаляем ноаую модель к миграции
  app.migrations.add(CreateUser())
  app.migrations.add(CreateAcronym())
  app.migrations.add(CreateCategory())
  app.migrations.add(CreateAcronymCategoryPivot())
  // 2
  app.logger.logLevel = .debug
  
  // 3
  try app.autoMigrate().wait()
  
  // register routes
  try routes(app)
}

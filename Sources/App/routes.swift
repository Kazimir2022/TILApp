import Fluent
import Vapor

func routes(_ app: Application) throws {
  
  // 1
  let acronymsController = AcronymsController()
  // 2
  try app.register(collection: acronymsController)

 // 1
  let usersController = UsersController()
  // 2
  try app.register(collection: usersController)
  
}

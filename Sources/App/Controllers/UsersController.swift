//
//  UsersController.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Vapor

// 1
struct UsersController: RouteCollection {
  // 2
  func boot(routes: RoutesBuilder) throws {
    // 3
    let usersRoute = routes.grouped("api", "users")
    // 4
    usersRoute.post(use: createHandler)
    
     // 1
    usersRoute.get(use: getAllHandler)
    // 2
    usersRoute.get(":userID", use: getHandler) 
  }

  // 5
  @Sendable func createHandler(_ req: Request)
    throws -> EventLoopFuture<User> {
    // 6
    let user = try req.content.decode(User.self)
    // 7
    return user.save(on: req.db).map { user }
  }
  
 // 1
  @Sendable func getAllHandler(_ req: Request)
    -> EventLoopFuture<[User]> {
    // 2
    User.query(on: req.db).all()
  }

  // 3
  @Sendable  func getHandler(_ req: Request)
    -> EventLoopFuture<User> {
    // 4
    User.find(req.parameters.get("userID"), on: req.db)
        .unwrap(or: Abort(.notFound))
  }
  
  
  
  
  
  
}

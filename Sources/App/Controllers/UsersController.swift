//
//  UsersController.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Vapor
@preconcurrency import JWT
import Fluent

// 1
struct UsersController: RouteCollection {
  // 2
  func boot(routes: RoutesBuilder) throws {
    let usersRoute = routes.grouped("api", "users")
    usersRoute.get(use: getAllHandler)
    usersRoute.get(":userID", use: getHandler)
    usersRoute.get(":userID", "acronyms", use: getAcronymsHandler)
    usersRoute.post("siwa", use: signInWithApple) 
    let basicAuthMiddleware = User.authenticator()
    let basicAuthGroup = usersRoute.grouped(basicAuthMiddleware)
    basicAuthGroup.post("login", use: loginHandler)
    
    let tokenAuthMiddleware = Token.authenticator()
    let guardAuthMiddleware = User.guardMiddleware()
    let tokenAuthGroup = usersRoute.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(use: createHandler)
  }
  
  @Sendable func createHandler(_ req: Request) throws -> EventLoopFuture<User.Public> {
    let user = try req.content.decode(User.self)
    user.password = try Bcrypt.hash(user.password)
    return user.save(on: req.db).map { user.convertToPublic() }
  }
  
  @Sendable func getAllHandler(_ req: Request) -> EventLoopFuture<[User.Public]> {
    User.query(on: req.db).all().convertToPublic()
  }
  
  @Sendable func getHandler(_ req: Request) -> EventLoopFuture<User.Public> {
    User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).convertToPublic()
  }
  
  @Sendable func getAcronymsHandler(_ req: Request) -> EventLoopFuture<[Acronym]> {
    User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
      user.$acronyms.get(on: req.db)
    }
  }
  
  @Sendable func loginHandler(_ req: Request) throws -> EventLoopFuture<Token> {
    let user = try req.auth.require(User.self)
    let token = try Token.generate(for: user)
    return token.save(on: req.db).map { token }
  }
  
  @Sendable func signInWithApple(_ req: Request)
  throws -> EventLoopFuture<Token> {
    // 1
    let data = try req.content.decode(SignInWithAppleToken.self)
    // 2
    guard let appIdentifier =
            Environment.get("IOS_APPLICATION_IDENTIFIER") else {
      throw Abort(.internalServerError)
    }
    // 3
    return req.jwt
      .apple
      .verify(data.token, applicationIdentifier: appIdentifier)
      .flatMap { siwaToken -> EventLoopFuture<Token> in
        // 4
        User.query(on: req.db)
          .filter(\.$siwaIdentifier == siwaToken.subject.value)
          .first()
          .flatMap { user in
            let userFuture: EventLoopFuture<User>
            if let user = user {
              userFuture = req.eventLoop.future(user)
            } else {
              // 5
              guard
                let email = siwaToken.email,
                let name = data.name
              else {
                return req.eventLoop
                  .future(error: Abort(.badRequest))
              }
              let user = User(
                name: name,
                username: email,
                password: UUID().uuidString,
                siwaIdentifier: siwaToken.subject.value)
              userFuture = user.save(on: req.db).map { user }
            }
            // 6
            return userFuture.flatMap { user in
              let token: Token
              do {
                // 7
                token = try Token.generate(for: user)
              } catch {
                return req.eventLoop.future(error: error)
              }
              // 8
              return token.save(on: req.db).map { token }
            }
          }
      }
  }
}

struct SignInWithAppleToken: Content {
  let token: String
  let name: String?
}

//
//  AcronymsController.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Vapor
import Fluent

struct AcronymsController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let acronymsRoutes = routes.grouped("api", "acronyms")
    acronymsRoutes.get(use: getAllHandler)
    acronymsRoutes.get(":acronymID", use: getHandler)
    acronymsRoutes.get("search", use: searchHandler)
    acronymsRoutes.get("first", use: getFirstHandler)
    acronymsRoutes.get("sorted", use: sortedHandler)
    acronymsRoutes.get(":acronymID", "user", use: getUserHandler)
    acronymsRoutes.get(":acronymID", "categories", use: getCategoriesHandler)

    let tokenAuthMiddleware = Token.authenticator()
    let guardAuthMiddleware = User.guardMiddleware()
    let tokenAuthGroup = acronymsRoutes.grouped(tokenAuthMiddleware, guardAuthMiddleware)
    tokenAuthGroup.post(use: createHandler)
    tokenAuthGroup.delete(":acronymID", use: deleteHandler)
    tokenAuthGroup.put(":acronymID", use: updateHandler)
    tokenAuthGroup.post(":acronymID", "categories", ":categoryID", use: addCategoriesHandler)
    tokenAuthGroup.delete(":acronymID", "categories", ":categoryID", use: removeCategoriesHandler)
  }

  @Sendable func getAllHandler(_ req: Request) -> EventLoopFuture<[Acronym]> {
    Acronym.query(on: req.db).all()
  }

  @Sendable func createHandler(_ req: Request) throws -> EventLoopFuture<Acronym> {
    let data = try req.content.decode(CreateAcronymData.self)
    let user = try req.auth.require(User.self)
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return acronym.save(on: req.db).map { acronym }
  }

  @Sendable func getHandler(_ req: Request) -> EventLoopFuture<Acronym> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
    .unwrap(or: Abort(.notFound))
  }

  @Sendable func updateHandler(_ req: Request) throws -> EventLoopFuture<Acronym> {
    let updateData = try req.content.decode(CreateAcronymData.self)
    let user = try req.auth.require(User.self)
    let userID = try user.requireID()
    return Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound)).flatMap { acronym in
        acronym.short = updateData.short
        acronym.long = updateData.long
        acronym.$user.id = userID
        return acronym.save(on: req.db).map {
          acronym
        }
    }
  }

  @Sendable func deleteHandler(_ req: Request)
    -> EventLoopFuture<HTTPStatus> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))
      .flatMap { acronym in
        acronym.delete(on: req.db)
          .transform(to: .noContent)
    }
  }

  @Sendable func searchHandler(_ req: Request) throws -> EventLoopFuture<[Acronym]> {
    guard let searchTerm = req
      .query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    return Acronym.query(on: req.db).group(.or) { or in
      or.filter(\.$short == searchTerm)
      or.filter(\.$long == searchTerm)
    }.all()
  }

  @Sendable func getFirstHandler(_ req: Request) -> EventLoopFuture<Acronym> {
    return Acronym.query(on: req.db)
      .first()
      .unwrap(or: Abort(.notFound))
  }

  @Sendable func sortedHandler(_ req: Request) -> EventLoopFuture<[Acronym]> {
    return Acronym.query(on: req.db).sort(\.$short, .ascending).all()
  }

  @Sendable func getUserHandler(_ req: Request) -> EventLoopFuture<User.Public> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
    .unwrap(or: Abort(.notFound))
    .flatMap { acronym in
      acronym.$user.get(on: req.db).convertToPublic()
    }
  }

  @Sendable func addCategoriesHandler(_ req: Request) -> EventLoopFuture<HTTPStatus> {
    let acronymQuery = Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound))
    let categoryQuery = Category.find(req.parameters.get("categoryID"), on: req.db).unwrap(or: Abort(.notFound))
    return acronymQuery.and(categoryQuery).flatMap { acronym, category in
      acronym.$categories.attach(category, on: req.db).transform(to: .created)
    }
  }

  @Sendable func getCategoriesHandler(_ req: Request) -> EventLoopFuture<[Category]> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
    .unwrap(or: Abort(.notFound))
    .flatMap { acronym in
      acronym.$categories.query(on: req.db).all()
    }
  }

  @Sendable func removeCategoriesHandler(_ req: Request) -> EventLoopFuture<HTTPStatus> {
    let acronymQuery = Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound))
    let categoryQuery = Category.find(req.parameters.get("categoryID"), on: req.db).unwrap(or: Abort(.notFound))
    return acronymQuery.and(categoryQuery).flatMap { acronym, category in
      acronym.$categories.detach(category, on: req.db).transform(to: .noContent)
    }
  }
}

struct CreateAcronymData: Content {
  let short: String
  let long: String
}

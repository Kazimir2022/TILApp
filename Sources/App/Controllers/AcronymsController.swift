//
//  AcronymsController.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Vapor
import Fluent

struct AcronymsController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {//регистрация маршрутов
    let acronymsRoutes = routes.grouped("api", "acronyms")// создание группы маршрутов для api/acronyms
    
    //routes.get("api", "acronyms", use: getAllHandler)
    acronymsRoutes.get(use: getAllHandler)
    // 1
    acronymsRoutes.post(use: createHandler)
    // 2
    acronymsRoutes.get(":acronymID", use: getHandler)
    // 3
    acronymsRoutes.put(":acronymID", use: updateHandler)
    // 4
    acronymsRoutes.delete(":acronymID", use: deleteHandler)
    // 5
    acronymsRoutes.get("search", use: searchHandler)
    // 6
    acronymsRoutes.get("first", use: getFirstHandler)
    // 7
    acronymsRoutes.get("sorted", use: sortedHandler)
  }
  
  
  @Sendable func getAllHandler(_ req: Request)
  -> EventLoopFuture<[Acronym]> {
    Acronym.query(on: req.db).all()
  }
  
  @Sendable func createHandler(_ req: Request) throws
  -> EventLoopFuture<Acronym> {
    let acronym = try req.content.decode(Acronym.self)
    return acronym.save(on: req.db).map { acronym }
  }
  
  @Sendable func getHandler(_ req: Request)
  -> EventLoopFuture<Acronym> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))
  }
  
  @Sendable func updateHandler(_ req: Request) throws
  -> EventLoopFuture<Acronym> {
    let updatedAcronym = try req.content.decode(Acronym.self)
    return Acronym.find(
      req.parameters.get("acronymID"),
      on: req.db)
    .unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.short = updatedAcronym.short
      acronym.long = updatedAcronym.long
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
  
  @Sendable func searchHandler(_ req: Request) throws
  -> EventLoopFuture<[Acronym]> {
    guard let searchTerm = req
      .query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    return Acronym.query(on: req.db).group(.or) { or in
      or.filter(\.$short == searchTerm)
      or.filter(\.$long == searchTerm)
    }.all()
  }
  
  @Sendable func getFirstHandler(_ req: Request)
  -> EventLoopFuture<Acronym> {
    return Acronym.query(on: req.db)
      .first()
      .unwrap(or: Abort(.notFound))
  }
  @Sendable  func sortedHandler(_ req: Request)
  -> EventLoopFuture<[Acronym]> {
    return Acronym.query(on: req.db)
      .sort(\.$short, .ascending).all()
  }
}

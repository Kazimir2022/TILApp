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
    // 1 Сохранение в БД
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
    
    acronymsRoutes.get(":acronymID", "user", use: getUserHandler)
  }
  
  
  @Sendable func getAllHandler(_ req: Request)
  -> EventLoopFuture<[Acronym]> {
    Acronym.query(on: req.db).all()
  }
  //Сохранение в БД
  @Sendable func createHandler(_ req: Request) throws
  -> EventLoopFuture<Acronym> {
    // 1 извлекаем из запроса модель нового типа - CreateAcronymData.self
    let data = try req.content.decode(CreateAcronymData.self)//извлекаем из запроса модель
    // 2 Создаем объект сохраняем его в заранее подготовленной для этого БД
    let acronym = Acronym(
      short: data.short,
      long: data.long,
      userID: data.userID)
    return acronym.save(on: req.db).map { acronym }
    
    /*
     
     let acronym = try req.content.decode(Acronym.self)
     return acronym.save(on: req.db).map { acronym }
     */
  }
  
  @Sendable func getHandler(_ req: Request)
  -> EventLoopFuture<Acronym> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))
  }
  
  @Sendable func updateHandler(_ req: Request) throws
  -> EventLoopFuture<Acronym> {
    let updateData =
    try req.content.decode(CreateAcronymData.self)
    return Acronym
      .find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))
      .flatMap { acronym in
        acronym.short = updateData.short
        acronym.long = updateData.long
        acronym.$user.id = updateData.userID
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
  // 1 Через модель Acronym получаем связанную запись User(получаем родителя)
  @Sendable  func getUserHandler(_ req: Request)
  -> EventLoopFuture<User> {
    //Возвращаем модель User а не Acronym
    // 2
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))
      .flatMap { acronym in
        // 3  получаем
        acronym.$user.get(on: req.db)
      }
  }
}

struct CreateAcronymData: Content {
  let short: String
  let long: String
  let userID: UUID
}

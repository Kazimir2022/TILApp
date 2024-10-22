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
  }
    //routes.get("api", "acronyms", use: getAllHandler)

  @Sendable func getAllHandler(_ req: Request)
            -> EventLoopFuture<[Acronym]> {
          Acronym.query(on: req.db).all()
  }
}

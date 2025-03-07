//
//  21-01-14-MakeCategoriesUnique.swift
//  TILApp
//
//  Created by Kazimir on 6.03.25.
//

import Fluent

struct MakeCategoriesUnique: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema(Category.v20210113.schemaName)
      .unique(on: Category.v20210113.name)
      .update()
  }

  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema(Category.v20210113.schemaName)
      .deleteUnique(on: Category.v20210113.name)
      .update()
  }
}

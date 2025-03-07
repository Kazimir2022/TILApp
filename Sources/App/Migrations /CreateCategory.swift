//
//  CreateCategory.swift
//  TILApp
//
//  Created by Kazimir on 29.10.24.
//

import Fluent

struct CreateCategory: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema(Category.v20210113.schemaName)
      .id()
      .field(Category.v20210113.name, .string, .required)
      .create()
  }
  
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema(Category.v20210113.schemaName).delete()
  }
}

extension Category {
  enum v20210113 {
    static let schemaName = "categories"
    static let id = FieldKey(stringLiteral: "id")
    static let name = FieldKey(stringLiteral: "name")
  }
}

//
//  CreateToken.swift
//  TILApp
//
//  Created by Kazimir on 6.03.25.
//

import Fluent

struct CreateToken: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema(Token.v20210113.schemaName)
      .id()
      .field(Token.v20210113.value, .string, .required)
      .field(Token.v20210113.userID, .uuid, .required, .references(User.v20210113.schemaName, User.v20210113.id, onDelete: .cascade))
      .create()
  }

  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema(Token.v20210113.schemaName).delete()
  }
}

extension Token {
  enum v20210113 {
    static let schemaName = "tokens"
    static let id = FieldKey(stringLiteral: "id")
    static let value = FieldKey(stringLiteral: "value")
    static let userID = FieldKey(stringLiteral: "userID")
  }
}


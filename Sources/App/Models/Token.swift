//
//  Token.swift
//  TILApp
//
//  Created by Kazimir on 6.03.25.
//

import Vapor
import Fluent

final class Token: Model, Content {
  static let schema = Token.v20210113.schemaName

  @ID
  var id: UUID?

  @Field(key: Token.v20210113.value)
  var value: String

  @Parent(key: Token.v20210113.userID)
  var user: User

  init() {}

  init(id: UUID? = nil, value: String, userID: User.IDValue) {
    self.id = id
    self.value = value
    self.$user.id = userID
  }
}

extension Token {
  static func generate(for user: User) throws -> Token {
    let random = [UInt8].random(count: 16).base64
    return try Token(value: random, userID: user.requireID())
  }
}

extension Token: ModelTokenAuthenticatable {
  static let valueKey = \Token.$value
  static let userKey = \Token.$user
  typealias User = App.User
  var isValid: Bool {
    true
  }
}

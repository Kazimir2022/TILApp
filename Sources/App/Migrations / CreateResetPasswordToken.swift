//
//   CreateResetPasswordToken.swift
//  TILApp
//
//  Created by Kazimir on 2.03.25.
//

import Fluent

struct CreateResetPasswordToken: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema("resetPasswordTokens")
      .id()
      .field("token", .string, .required)
      .field(
        "userID",
        .uuid,
        .required,
        .references("users", "id"))
      .unique(on: "token")
      .create()
  }

  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("resetPasswordTokens").delete()
  }
}

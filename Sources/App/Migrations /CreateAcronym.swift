//
//  CreateAcronym.swift
//  TILApp
//
//  Created by Kazimir on 9.10.24.
//

import Fluent

// 1
struct CreateAcronym: Migration {
  // 2
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3
    database.schema("acronyms")
      // 4
      .id()
      // 5 Свойство добавили- добавляем столбец в БД
      .field("short", .string, .required)
      .field("long", .string, .required)
      // .field("userID", .uuid, .required)
      .field("userID", .uuid, .required, .references("users", "id"))
      // 6
      .create()
  }
  
  // 7
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("acronyms").delete()
  }
}


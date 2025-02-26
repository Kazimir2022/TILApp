//
//  CreateUser.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Fluent

// 1
struct CreateUser: Migration {
  // 2
  func prepare(on database: Database) -> EventLoopFuture<Void> {
     
    database.schema("users")
    .id()
    .field("name", .string, .required)
    .field("username", .string, .required)
    .field("password", .string, .required)
    .unique(on: "username")
    .create()
  }
  
  // 7
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("users").delete()
  }
} 

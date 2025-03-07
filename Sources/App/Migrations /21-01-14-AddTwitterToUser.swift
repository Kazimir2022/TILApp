//
//  21-01-14-AddTwitterToUser.swift
//  TILApp
//
//  Created by Kazimir on 6.03.25.
//

import Fluent

struct AddTwitterURLToUser: Migration {
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    database.schema(User.v20210113.schemaName)
      .field(User.v20210114.twitterURL, .string)
      .update()//Вызовите update() для выполнения миграции и обновления таблицы.
  }

  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema(User.v20210113.schemaName)
      .deleteField(User.v20210114.twitterURL)
      .update()
  }
}

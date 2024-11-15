//
//  CreateAcronymCategoryPivot.swift
//  TILApp
//
//  Created by Kazimir on 14.11.24.
//

import Fluent

// 1
struct CreateAcronymCategoryPivot: Migration {
  // 2
  func prepare(on database: Database) -> EventLoopFuture<Void> {
    // 3
    database.schema("acronym-category-pivot")
      // 4
      .id()
      // 5 Без ограничения можно удалить acronum и category
        //каскадное ограничение - база сама удаляет связь 
      .field("acronymID", .uuid, .required,
        .references("acronyms", "id", onDelete: .cascade))
      .field("categoryID", .uuid, .required,
        .references("categories", "id", onDelete: .cascade))
      // 6
      .create()
  }
  
  // 7
  func revert(on database: Database) -> EventLoopFuture<Void> {
    database.schema("acronym-category-pivot").delete()
  }
}

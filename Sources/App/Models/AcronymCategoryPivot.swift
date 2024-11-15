//
//  AcronymCategoryPivot.swift
//  TILApp
//
//  Created by Kazimir on 29.10.24.
//

import Fluent
import Foundation
//Vapor не импортируем для опоры зато импортируем Foundation для uuid
// 1
final class AcronymCategoryPivot: Model {
  static let schema = "acronym-category-pivot"
  
  // 2
  @ID
  var id: UUID?
  
  // 3 ссылка на каждого родителя
  @Parent(key: "acronymID")
  var acronym: Acronym  // одна аббревиатура
  
  @Parent(key: "categoryID")
  var category: Category // одна аббревиатура
  
  // 4
  init() {}
  
  // 5
  init(
    id: UUID? = nil,
    acronym: Acronym,
    category: Category
  ) throws {
    self.id = id
    self.$acronym.id = try acronym.requireID()// requireID()-проверка того что модели имеют ID
    self.$category.id = try category.requireID()
  }
}
 

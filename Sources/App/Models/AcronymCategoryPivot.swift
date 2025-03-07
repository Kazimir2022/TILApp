//
//  AcronymCategoryPivot.swift
//  TILApp
//
//  Created by Kazimir on 29.10.24.
//

import Fluent
import Foundation

final class AcronymCategoryPivot: Model {
  static let schema = AcronymCategoryPivot.v20210113.schemaName
  
  @ID
  var id: UUID?
  
  @Parent(key: AcronymCategoryPivot.v20210113.acronymID)
  var acronym: Acronym
  
  @Parent(key: AcronymCategoryPivot.v20210113.categoryID)
  var category: Category
  
  init() {}
  
  init(id: UUID? = nil, acronym: Acronym, category: Category) throws {
    self.id = id
    self.$acronym.id = try acronym.requireID()
    self.$category.id = try category.requireID()
  }
}

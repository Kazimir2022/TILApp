//
//  User.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Fluent
import Vapor

final class User: Model, Content {
  static let schema = "users"
    
  @ID
  var id: UUID?
   
  @Field(key: "name")
  var name: String
   
  @Field(key: "username")
  var username: String
  
  @Children(for: \.$user)//указываем имя родительского свойства
  var acronyms: [Acronym]
  init() {}
    
  init(id: UUID? = nil, name: String, username: String) {
    self.name = name
    self.username = username
  }
}

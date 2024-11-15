//
//  Acronym.swift
//  TILApp
//
//  Created by Kazimir on 9.10.24.
//

import Vapor
import Fluent

// 1
final class Acronym: Model {
  // 2
  static let schema = "acronyms"
  
  // 3
  @ID
  var id: UUID?
  
  // 4
  @Field(key: "short")
  var short: String
  
  @Field(key: "long")
  var long: String
    //ссылка на user. Абревиатура является дочерью. @Parent также позволяет создавать аббревиатуру, используя только идентификатор пользователя, без необходимости в полном объекте пользователя. Это помогает избежать дополнительных запросов к базе данных.
  @Parent(key: "userID")// ключ - придумываем любой.
  var user: User
  
    
  // c помощью этой ссылки можно получить category
 @Siblings(
    through: AcronymCategoryPivot.self,
    from: \.$acronym,
    to: \.$category)
  var categories: [Category] 
   
  // 5
  init() {}
  
  // 1
  init(
    id: UUID? = nil,
    short: String,
    long: String,
    userID: User.IDValue // новый параметр userID(у параметров могут быть любые имена)
          // при поможи обертки  @Parent, а также протокола Model, получаем IDValue(это id User)
  ) {
    self.id = id
    self.short = short
    self.long = long
    // 2 Сам объект нас неинтересует, только его id
    //Устанавливаем id прогнозируемого значения userID
    self.$user.id = userID// устанавливаем идентификатор обертки свойств
  }
}

extension Acronym: Content {}

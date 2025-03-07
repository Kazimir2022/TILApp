//
//  User.swift
//  TILApp
//
//  Created by Kazimir on 22.10.24.
//

import Fluent
import Vapor

final class User: Model, Content {
  static let schema = User.v20210113.schemaName
  
  @ID
  var id: UUID?
  
  @Field(key: User.v20210113.name)
  var name: String
  
  @Field(key: User.v20210113.username)
  var username: String

  @Field(key: User.v20210113.password)
  var password: String
  
  @Children(for: \.$user)
  var acronyms: [Acronym]

  @OptionalField(key: User.v20210114.twitterURL)
  var twitterURL: String?
  
  init() {}
  
  init(id: UUID? = nil, name: String, username: String, password: String, twitterURL: String? = nil) {
    self.name = name
    self.username = username
    self.password = password
    self.twitterURL = twitterURL
  }

  final class Public: Content {
    var id: UUID?
    var name: String
    var username: String

    init(id: UUID?, name: String, username: String) {
      self.id = id
      self.name = name
      self.username = username
    }
  }

  final class PublicV2: Content {
    var id: UUID?
    var name: String
    var username: String
    var twitterURL: String?

    init(id: UUID?,
         name: String,
         username: String,
         twitterURL: String? = nil) {
      self.id = id
      self.name = name
      self.username = username
      self.twitterURL = twitterURL
    }
  }
}

extension User {
  func convertToPublic() -> User.Public {
    return User.Public(id: id, name: name, username: username)
  }

  func convertToPublicV2() -> User.PublicV2 {
    return User.PublicV2(id: id, name: name, username: username, twitterURL: twitterURL)
  }
}

extension EventLoopFuture where Value: User {
  func convertToPublic() -> EventLoopFuture<User.Public> {
    return self.map { user in
      return user.convertToPublic()
    }
  }

  func convertToPublicV2() -> EventLoopFuture<User.PublicV2> {
    return self.map { user in
      return user.convertToPublicV2()
    }
  }
}

extension Collection where Element: User {
  func convertToPublic() -> [User.Public] {
    return self.map { $0.convertToPublic() }
  }

  func convertToPublicV2() -> [User.PublicV2] {
    return self.map { $0.convertToPublicV2() }
  }
}

extension EventLoopFuture where Value == Array<User> {
  func convertToPublic() -> EventLoopFuture<[User.Public]> {
    return self.map { $0.convertToPublic() }
  }

  func convertToPublicV2() -> EventLoopFuture<[User.PublicV2]> {
    return self.map { $0.convertToPublicV2() }
  }
}

extension User: ModelAuthenticatable {
  static let usernameKey = \User.$username
  static let passwordHashKey = \User.$password

  func verify(password: String) throws -> Bool {
    try Bcrypt.verify(password, created: self.password)
  }
}

extension User: ModelSessionAuthenticatable {}
extension User: ModelCredentialsAuthenticatable {}

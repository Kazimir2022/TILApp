//
//  WebsiteController.swift
//  TILApp
//
//  Created by Kazimir on 26.02.25.
//

import Vapor
import Fluent
import SendGrid

struct WebsiteController: RouteCollection {
  func boot(routes: RoutesBuilder) throws {
    let authSessionsRoutes = routes.grouped(User.sessionAuthenticator())
    authSessionsRoutes.get("login", use: loginHandler)
    let credentialsAuthRoutes = authSessionsRoutes.grouped(User.credentialsAuthenticator())
    credentialsAuthRoutes.post("login", use: loginPostHandler)
    authSessionsRoutes.post("logout", use: logoutHandler)
    authSessionsRoutes.get("register", use: registerHandler)
    authSessionsRoutes.post("register", use: registerPostHandler)
    authSessionsRoutes.post("login", "siwa", "callback", use: appleAuthCallbackHandler)
    authSessionsRoutes.post("login", "siwa", "handle", use: appleAuthRedirectHandler)
    authSessionsRoutes.get("forgottenPassword", use: forgottenPasswordHandler)
    authSessionsRoutes.post("forgottenPassword", use: forgottenPasswordPostHandler)
    authSessionsRoutes.get("resetPassword", use: resetPasswordHandler)
    authSessionsRoutes.post("resetPassword", use: resetPasswordPostHandler)
    
    authSessionsRoutes.get(use: indexHandler)
    authSessionsRoutes.get("acronyms", ":acronymID", use: acronymHandler)
    authSessionsRoutes.get("users", ":userID", use: userHandler)
    authSessionsRoutes.get("users", use: allUsersHandler)
    authSessionsRoutes.get("categories", use: allCategoriesHandler)
    authSessionsRoutes.get("categories", ":categoryID", use: categoryHandler)
    
    let protectedRoutes = authSessionsRoutes.grouped(User.redirectMiddleware(path: "/login"))
    protectedRoutes.get("acronyms", "create", use: createAcronymHandler)
    protectedRoutes.post("acronyms", "create", use: createAcronymPostHandler)
    protectedRoutes.get("acronyms", ":acronymID", "edit", use: editAcronymHandler)
    protectedRoutes.post("acronyms", ":acronymID", "edit", use: editAcronymPostHandler)
    protectedRoutes.post("acronyms", ":acronymID", "delete", use: deleteAcronymHandler)
  }
  
  @Sendable func indexHandler(_ req: Request) -> EventLoopFuture<View> {
    Acronym.query(on: req.db).all().flatMap { acronyms in
      let userLoggedIn = req.auth.has(User.self)
      let showCookieMessage = req.cookies["cookies-accepted"] == nil
      let context = IndexContext(title: "Home page", acronyms: acronyms, userLoggedIn: userLoggedIn, showCookieMessage: showCookieMessage)
      return req.view.render("index", context)
    }
  }
  
  @Sendable func acronymHandler(_ req: Request) -> EventLoopFuture<View> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      let userFuture = acronym.$user.get(on: req.db)
      let categoriesFuture = acronym.$categories.query(on: req.db).all()
      return userFuture.and(categoriesFuture).flatMap { user, categories in
        let context = AcronymContext(
          title: acronym.short,
          acronym: acronym,
          user: user,
          categories: categories)
        return req.view.render("acronym", context)
      }
    }
  }
  
  @Sendable func userHandler(_ req: Request) -> EventLoopFuture<View> {
    User.find(req.parameters.get("userID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { user in
      user.$acronyms.get(on: req.db).flatMap { acronyms in
        let context = UserContext(title: user.name, user: user, acronyms: acronyms)
        return req.view.render("user", context)
      }
    }
  }
  
  @Sendable func allUsersHandler(_ req: Request) -> EventLoopFuture<View> {
    User.query(on: req.db).all().flatMap { users in
      let context = AllUsersContext(
        title: "All Users",
        users: users)
      return req.view.render("allUsers", context)
    }
  }
  
  @Sendable func allCategoriesHandler(_ req: Request) -> EventLoopFuture<View> {
    Category.query(on: req.db).all().flatMap { categories in
      let context = AllCategoriesContext(categories: categories)
      return req.view.render("allCategories", context)
    }
  }
  
  @Sendable func categoryHandler(_ req: Request) -> EventLoopFuture<View> {
    Category.find(req.parameters.get("categoryID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { category in
      category.$acronyms.get(on: req.db).flatMap { acronyms in
        let context = CategoryContext(title: category.name, category: category, acronyms: acronyms)
        return req.view.render("category", context)
      }
    }
  }
  
  @Sendable func createAcronymHandler(_ req: Request) -> EventLoopFuture<View> {
    let token = [UInt8].random(count: 16).base64
    let context = CreateAcronymContext(csrfToken: token)
    req.session.data["CSRF_TOKEN"] = token
    return req.view.render("createAcronym", context)
  }
  
  @Sendable func createAcronymPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let data = try req.content.decode(CreateAcronymFormData.self)
    let user = try req.auth.require(User.self)
    
    let expectedToken = req.session.data["CSRF_TOKEN"]
    req.session.data["CSRF_TOKEN"] = nil
    guard
      let csrfToken = data.csrfToken,
      expectedToken == csrfToken
    else {
      throw Abort(.badRequest)
    }
    
    let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
    return acronym.save(on: req.db).flatMap {
      guard let id = acronym.id else {
        return req.eventLoop.future(error: Abort(.internalServerError))
      }
      var categorySaves: [EventLoopFuture<Void>] = []
      for category in data.categories ?? [] {
        categorySaves.append(Category.addCategory(category, to: acronym, on: req))
      }
      let redirect = req.redirect(to: "/acronyms/\(id)")
      return categorySaves.flatten(on: req.eventLoop).transform(to: redirect)
    }
  }
  
  @Sendable func editAcronymHandler(_ req: Request) -> EventLoopFuture<View> {
    return Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.$categories.get(on: req.db).flatMap { categories in
        let context = EditAcronymContext(acronym: acronym, categories: categories)
        return req.view.render("createAcronym", context)
      }
    }
  }
  
  @Sendable func editAcronymPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let user = try req.auth.require(User.self)
    let userID = try user.requireID()
    let updateData = try req.content.decode(CreateAcronymFormData.self)
    return Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.short = updateData.short
      acronym.long = updateData.long
      acronym.$user.id = userID
      guard let id = acronym.id else {
        return req.eventLoop.future(error: Abort(.internalServerError))
      }
      return acronym.save(on: req.db).flatMap {
        acronym.$categories.get(on: req.db)
      }.flatMap { existingCategories in
        let existingStringArray = existingCategories.map {
          $0.name
        }
        
        let existingSet = Set<String>(existingStringArray)
        let newSet = Set<String>(updateData.categories ?? [])
        
        let categoriesToAdd = newSet.subtracting(existingSet)
        let categoriesToRemove = existingSet.subtracting(newSet)
        
        var categoryResults: [EventLoopFuture<Void>] = []
        for newCategory in categoriesToAdd {
          categoryResults.append(Category.addCategory(newCategory, to: acronym, on: req))
        }
        
        for categoryNameToRemove in categoriesToRemove {
          let categoryToRemove = existingCategories.first {
            $0.name == categoryNameToRemove
          }
          if let category = categoryToRemove {
            categoryResults.append(
              acronym.$categories.detach(category, on: req.db))
          }
        }
        
        let redirect = req.redirect(to: "/acronyms/\(id)")
        return categoryResults.flatten(on: req.eventLoop).transform(to: redirect)
      }
    }
  }
  
  @Sendable func deleteAcronymHandler(_ req: Request) -> EventLoopFuture<Response> {
    Acronym.find(req.parameters.get("acronymID"), on: req.db).unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.delete(on: req.db).transform(to: req.redirect(to: "/"))
    }
  }
  
  @Sendable func loginHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let context: LoginContext
    let siwaContext = try buildSIWAContext(on: req)
    if let error = req.query[Bool.self, at: "error"], error {
      context = LoginContext(loginError: true, siwaContext: siwaContext)
    } else {
      context = LoginContext(siwaContext: siwaContext)
    }
    return req.view.render("login", context).encodeResponse(for: req).map { response in
      let expiryDate = Date().addingTimeInterval(300)
      let cookie = HTTPCookies.Value(string: siwaContext.state, expires: expiryDate, maxAge: 300, isHTTPOnly: true, sameSite: HTTPCookies.SameSitePolicy.none)
      response.cookies["SIWA_STATE"] = cookie
      return response
    }
  }
  
  @Sendable func loginPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    if req.auth.has(User.self) {
      return req.eventLoop.future(req.redirect(to: "/"))
    } else {
      let siwaContext = try buildSIWAContext(on: req)
      let context = LoginContext(loginError: true, siwaContext: siwaContext)
      return req.view.render("login", context).encodeResponse(for: req).map { response in
        let expiryDate = Date().addingTimeInterval(300)
        let cookie = HTTPCookies.Value(string: siwaContext.state, expires: expiryDate, maxAge: 300, isHTTPOnly: true, sameSite: HTTPCookies.SameSitePolicy.none)
        response.cookies["SIWA_STATE"] = cookie
        return response
      }
    }
  }
  
  @Sendable func logoutHandler(_ req: Request) -> Response {
    req.auth.logout(User.self)
    return req.redirect(to: "/")
  }
  
  @Sendable func registerHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let siwaContext = try buildSIWAContext(on: req)
    let context: RegisterContext
    if let message = req.query[String.self, at: "message"] {
      context = RegisterContext(message: message, siwaContext: siwaContext)
    } else {
      context = RegisterContext(siwaContext: siwaContext)
    }
    return req.view.render("register", context).encodeResponse(for: req).map { response in
      let expiryDate = Date().addingTimeInterval(300)
      let cookie = HTTPCookies.Value(string: siwaContext.state, expires: expiryDate, maxAge: 300, isHTTPOnly: true, sameSite: HTTPCookies.SameSitePolicy.none)
      response.cookies["SIWA_STATE"] = cookie
      return response
    }
  }
  
  @Sendable func registerPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    do {
      try RegisterData.validate(content: req)
    } catch let error as ValidationsError {
      let message = error.description.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Unknown error"
      return req.eventLoop.future(req.redirect(to: "/register?message=\(message)"))
    }
    let data = try req.content.decode(RegisterData.self)
    let password = try Bcrypt.hash(data.password)
    let user = User(
      name: data.name,
      username: data.username,
      password: password,
      email: data.emailAddress)
    return user.save(on: req.db).map {
      req.auth.login(user)
      return req.redirect(to: "/")
    }
  }
  
  @Sendable func appleAuthCallbackHandler(_ req: Request) throws -> EventLoopFuture<View> {
    let siwaData = try req.content.decode(AppleAuthorizationResponse.self)
    guard
      let sessionState = req.cookies["SIWA_STATE"]?.string,
      !sessionState.isEmpty,
      sessionState == siwaData.state
    else {
      req.logger.warning("SIWA does not exist or does not match")
      throw Abort(.unauthorized)
    }
    let context = SIWAHandleContext(token: siwaData.idToken, email: siwaData.user?.email, firstName: siwaData.user?.name?.firstName, lastName: siwaData.user?.name?.lastName)
    return req.view.render("siwaHandler", context)
  }
  
  @Sendable func appleAuthRedirectHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let data = try req.content.decode(SIWARedirectData.self)
    guard let appIdentifier = Environment.get("WEBSITE_APPLICATION_IDENTIFIER") else {
      throw Abort(.internalServerError)
    }
    return req.jwt.apple.verify(data.token, applicationIdentifier: appIdentifier).flatMap { siwaToken in
      User.query(on: req.db).filter(\.$siwaIdentifier == siwaToken.subject.value).first().flatMap { user in
        let userFuture: EventLoopFuture<User>
        if let user = user {
          userFuture = req.eventLoop.future(user)
        } else {
          guard
            let email = data.email,
            let firstName = data.firstName,
            let lastName = data.lastName
          else {
            return req.eventLoop.future(error: Abort(.badRequest))
          }
          let user = User(
            name: "\(firstName) \(lastName)",
            username: email,
            password: UUID().uuidString,
            siwaIdentifier: siwaToken.subject.value,
            email: email)
          userFuture = user.save(on: req.db).map { user }
        }
        return userFuture.map { user in
          req.auth.login(user)
          return req.redirect(to: "/")
        }
      }
    }
  }
  
  private func buildSIWAContext(on req: Request) throws -> SIWAContext {
    let state = [UInt8].random(count: 32).base64
    let scopes = "name email"
    guard let clientID = Environment.get("WEBSITE_APPLICATION_IDENTIFIER") else {
      req.logger.error("WEBSITE_APPLICATION_IDENTIFIER not set")
      throw Abort(.internalServerError)
    }
    guard let redirectURI = Environment.get("SIWA_REDIRECT_URL") else {
      req.logger.error("SIWA_REDIRECT_URL not set")
      throw Abort(.internalServerError)
    }
    let siwa = SIWAContext(clientID: clientID, scopes: scopes, redirectURI: redirectURI, state: state)
    return siwa
  }
  @Sendable func forgottenPasswordHandler(_ req: Request) -> EventLoopFuture<View> {
    req.view.render("forgottenPassword", ["title": "Reset Your Password"])
  }
  
  @Sendable func forgottenPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<View> {
    let email = try req.content.get(String.self, at: "email")
    return User.query(on: req.db).filter(\.$email == email).first().flatMap { user in
      guard let user = user else {
        return req.view.render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
      }
      let resetTokenString = Data([UInt8].random(count: 32)).base32EncodedString()
      let resetToken: ResetPasswordToken
      do {
        resetToken = try ResetPasswordToken(token: resetTokenString, userID: user.requireID())
      } catch {
        return req.eventLoop.future(error: error)
      }
      return resetToken.save(on: req.db).flatMap {
        let emailContent = """
        <p>You've requested to reset your password. <a
        href="http://localhost:8080/resetPassword?\
        token=\(resetTokenString)">
        Click here</a> to reset your password.</p>
        """
        let emailAddress = EmailAddress(email: user.email, name: user.name)
        let fromEmail = EmailAddress(email: "0xtimc@gmail.com", name: "Vapor TIL")
        let emailConfig = Personalization(to: [emailAddress], subject: "Reset Your Password")
        let email = SendGridEmail(
          personalizations: [emailConfig],
          from: fromEmail,
          content: [["type": "text/html", "value": emailContent]])
        let emailSend: EventLoopFuture<Void>
        do {
          emailSend = try req.application.sendgrid.client.send(email: email, on: req.eventLoop)
        } catch {
          return req.eventLoop.future(error: error)
        }
        return emailSend.flatMap {
          req.view.render("forgottenPasswordConfirmed", ["title": "Password Reset Email Sent"])
        }
      }
    }
  }
  
  @Sendable func resetPasswordHandler(_ req: Request) -> EventLoopFuture<View> {
    guard let token = try? req.query.get(String.self, at: "token") else {
      return req.view.render(
        "resetPassword",
        ResetPasswordContext(error: true)
      )
    }
    return ResetPasswordToken.query(on: req.db).filter(\.$token == token).first()
      .unwrap(or: Abort.redirect(to: "/"))
      .flatMap { token in
        token.$user.get(on: req.db).flatMap { user in
          do {
            try req.session.set("ResetPasswordUser", to: user)
          } catch {
            return req.eventLoop.future(error: error)
          }
          return token.delete(on: req.db)
        }
      }.flatMap {
        req.view.render("resetPassword", ResetPasswordContext()
        )
      }
  }
  
  @Sendable func resetPasswordPostHandler(_ req: Request) throws -> EventLoopFuture<Response> {
    let data = try req.content.decode(ResetPasswordData.self)
    guard data.password == data.confirmPassword else {
      return req.view.render("resetPassword", ResetPasswordContext(error: true))
        .encodeResponse(for: req)
    }
    let resetPasswordUser = try req.session.get("ResetPasswordUser", as: User.self)
    req.session.data["ResetPasswordUser"] = nil
    let newPassword = try Bcrypt.hash(data.password)
    return try User.query(on: req.db)
      .filter(\.$id == resetPasswordUser.requireID())
      .set(\.$password, to: newPassword)
      .update()
      .transform(to: req.redirect(to: "/login"))
  }
}

struct IndexContext: Encodable {
  let title: String
  let acronyms: [Acronym]
  let userLoggedIn: Bool
  let showCookieMessage: Bool
}

struct AcronymContext: Encodable {
  let title: String
  let acronym: Acronym
  let user: User
  let categories: [Category]
}

struct UserContext: Encodable {
  let title: String
  let user: User
  let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
  let title: String
  let users: [User]
}

struct AllCategoriesContext: Encodable {
  let title = "All Categories"
  let categories: [Category]
}

struct CategoryContext: Encodable {
  let title: String
  let category: Category
  let acronyms: [Acronym]
}

struct CreateAcronymContext: Encodable {
  let title = "Create An Acronym"
  let csrfToken: String
}

struct EditAcronymContext: Encodable {
  let title = "Edit Acronym"
  let acronym: Acronym
  let editing = true
  let categories: [Category]
}

struct CreateAcronymFormData: Content {
  let short: String
  let long: String
  let categories: [String]?
  let csrfToken: String?
}

struct LoginContext: Encodable {
  let title = "Log In"
  let loginError: Bool
  let siwaContext: SIWAContext
  
  init(loginError: Bool = false, siwaContext: SIWAContext) {
    self.loginError = loginError
    self.siwaContext = siwaContext
  }
}

struct RegisterContext: Encodable {
  let title = "Register"
  let message: String?
  let siwaContext: SIWAContext
  
  init(message: String? = nil, siwaContext: SIWAContext) {
    self.message = message
    self.siwaContext = siwaContext
  }
}

struct RegisterData: Content {
  let name: String
  let username: String
  let password: String
  let confirmPassword: String
  let emailAddress: String
}

extension RegisterData: Validatable {
  public static func validations(_ validations: inout Validations) {
    validations.add("name", as: String.self, is: .ascii)
    validations.add("username", as: String.self, is: .alphanumeric && .count(3...))
    validations.add("password", as: String.self, is: .count(8...))
    validations.add("zipCode", as: String.self, is: .zipCode, required: false)
    validations.add("emailAddress", as: String.self, is: .email)
  }
}

extension ValidatorResults {
  struct ZipCode {
    let isValidZipCode: Bool
  }
}

extension ValidatorResults.ZipCode: ValidatorResult {
  var isFailure: Bool {
    !isValidZipCode
  }
  
  var successDescription: String? {
    "is a valid zip code"
  }
  
  var failureDescription: String? {
    "is not a valid zip code"
  }
}

extension Validator where T == String {
  private static var zipCodeRegex: String {
    "^\\d{5}(?:[-\\s]\\d{4})?$"
  }
  
  public static var zipCode: Validator<T> {
    Validator { input -> ValidatorResult in
      guard
        let range = input.range(of: zipCodeRegex, options: [.regularExpression]),
        range.lowerBound == input.startIndex && range.upperBound == input.endIndex
      else {
        return ValidatorResults.ZipCode(isValidZipCode: false)
      }
      return ValidatorResults.ZipCode(isValidZipCode: true)
    }
  }
}

struct AppleAuthorizationResponse: Decodable {
  struct User: Decodable {
    struct Name: Decodable {
      let firstName: String?
      let lastName: String?
    }
    let email: String
    let name: Name?
  }
  
  let code: String
  let state: String
  let idToken: String
  let user: User?
  
  enum CodingKeys: String, CodingKey {
    case code
    case state
    case idToken = "id_token"
    case user
  }
  
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    code = try values.decode(String.self, forKey: .code)
    state = try values.decode(String.self, forKey: .state)
    idToken = try values.decode(String.self, forKey: .idToken)
    
    if let jsonString = try values.decodeIfPresent(String.self, forKey: .user),
       let jsonData = jsonString.data(using: .utf8) {
      user = try JSONDecoder().decode(User.self, from: jsonData)
    } else {
      user = nil
    }
  }
}

struct SIWAHandleContext: Encodable {
  let token: String
  let email: String?
  let firstName: String?
  let lastName: String?
}

struct SIWARedirectData: Content {
  let token: String
  let email: String?
  let firstName: String?
  let lastName: String?
}

struct SIWAContext: Encodable {
  let clientID: String
  let scopes: String
  let redirectURI: String
  let state: String
}

struct ResetPasswordContext: Encodable {
  let title = "Reset Password"
  let error: Bool?
  
  init(error: Bool? = false) {
    self.error = error
  }
}

struct ResetPasswordData: Content {
  let password: String
  let confirmPassword: String
}


//
//  UserTests.swift
//  TILApp
//
//  Created by Kazimir on 15.11.24.
//

@testable import App//импортируем модуль для тестовых целей
import XCTVapor

final class UserTests: XCTestCase {
  let usersName = "Alice"
  let usersUsername = "alicea"
  let usersURI = "/api/users/"
  var app: Application!
  
  override func setUpWithError() throws {
     app = try Application.testable()
   }
   
   override func tearDownWithError() throws {
     app.shutdown()
   }
  //получение Users из api
  func testUsersCanBeRetrievedFromAPI() throws {
    let user = try User.create(
      name: usersName,
      username: usersUsername,
      on: app.db)
    _ = try User.create(on: app.db)

    try app.test(.GET, usersURI, afterResponse: { response in
      XCTAssertEqual(response.status, .ok)
      let users = try response.content.decode([User].self)
      
      XCTAssertEqual(users.count, 2)
      XCTAssertEqual(users[0].name, usersName)
      XCTAssertEqual(users[0].username, usersUsername)
      XCTAssertEqual(users[0].id, user.id)
    })
  }
  //проверка сохранения пользывателя из api
  func testUserCanBeSavedWithAPI() throws {
    // 1 создаем экземпляр User со значениями которые сохранили вверху класса
    let user = User(name: usersName, username: usersUsername)
    
    // 2 создаем пост запрос перед которым выполняем замыкание
    try app.test(.POST, usersURI, beforeRequest: { req in
      // 3 Кодируем данные для последующей отправки
      try req.content.encode(user)
    }, afterResponse: { response in
      // 4 Декодируем тело ответа в модель User
      let receivedUser = try response.content.decode(User.self)
      // 5 Полученные данные из ответа сравниваем с данными которые указыны вверху класса
      XCTAssertEqual(receivedUser.name, usersName)
      XCTAssertEqual(receivedUser.username, usersUsername)
      XCTAssertNotNil(receivedUser.id)
      
      // 6 созд гет запрос, получив ответ выполняем замыкание
      try app.test(.GET, usersURI,
        afterResponse: { secondResponse in
          // 7 Получем массив всех пользывателей
          let users =
            try secondResponse.content.decode([User].self)
        XCTAssertEqual(users.count, 1)//количество пользывателей равен 1
        XCTAssertEqual(users[0].name, usersName) // данные совпадают с данными которые указаны вверху
          XCTAssertEqual(users[0].username, usersUsername)
          XCTAssertEqual(users[0].id, receivedUser.id)
        })
    })
  }
  //получение одного пользывателя из Api
   func testGettingASingleUserFromTheAPI() throws {
    // 1 Сохранение пользывателя в БД
    let user = try User.create(
      name: usersName,
      username: usersUsername,
      on: app.db)
    
    // 2 Созд гет запрос, получем ответ, извлекаем пользывателя
    try app.test(.GET, "\(usersURI)\(user.id!)",
      afterResponse: { response in
        let receivedUser = try response.content.decode(User.self)
        // 3
      XCTAssertEqual(receivedUser.name, usersName)//проверка данных
        XCTAssertEqual(receivedUser.username, usersUsername)
        XCTAssertEqual(receivedUser.id, user.id)
      })
  }
    //проверка получения аббревиатур пользывателя
   func testGettingAUsersAcronymsFromTheAPI() throws {
    // 1 Создаем пользывател Люк и сохраняем его в БД
    let user = try User.create(on: app.db)
    // 2 Определяем ожидаемые значения для аббревиатур
    let acronymShort = "OMG"
    let acronymLong = "Oh My God"
    
    // 3 Сохр в БД аббревиатуры исп пользывателя
     //сохр еще одной аббревиатуры
    let acronym1 = try Acronym.create(
      short: acronymShort,
      long: acronymLong,
      user: user,
      on: app.db)
     _ = try Acronym.create(
      short: "LOL",
      long: "Laugh Out Loud",
      user: user,
      on: app.db)

    // 4 Отправив Гет запрос получаем аббревиатуры
    try app.test(.GET, "\(usersURI)\(user.id!)/acronyms",
      afterResponse: { response in
        let acronyms = try response.content.decode([Acronym].self)
        // 5
      XCTAssertEqual(acronyms.count, 2)//проверяем что их две
      XCTAssertEqual(acronyms[0].id, acronym1.id)//проеряем что первая аббр соответствует ожидаемым значения
        XCTAssertEqual(acronyms[0].short, acronymShort)
        XCTAssertEqual(acronyms[0].long, acronymLong)
      })
  }
}


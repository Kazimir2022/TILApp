//
//  UserTests.swift
//  TILApp
//
//  Created by Kazimir on 15.11.24.
//

@testable import App//импортируем модуль для тестовых целей
import XCTVapor

final class UserTests: XCTestCase {
  func testUsersCanBeRetrievedFromAPI() async throws {
    // 1
    let expectedName = "Alice"
    let expectedUsername = "alice"

    // 2 Создаем приложение(с помощью XCTVapor)/созд тестовый модуль
    let app = Application(.testing)
    // 3 по окончании работы освобождаем ресурсы
    defer { app.shutdown() }
    // 4 наше тестовое приложение вызывает туже конфигурацию
    try await configure(app)
    try app.autoRevert().wait()//отмена любых миграций которые были ранее
    try app.autoMigrate().wait()//запуск новой миграции

    // 5 создаем экземпляр User
    let user = User(
      name: expectedName,
      username: expectedUsername)
   try user.save(on: app.db).wait()//сохр экземпляр  в БД. Исп wait тк не работаем с EventLoopFuture
    try User(name: "Luke", username: "lukes")
     .save(on: app.db) // сохраняем еще один экземпляр
      .wait()

    // 6 Используя модуль тестирования создаем get запрос, после получения ответа выполним замыкание
    try app.test(.GET, "/api/users", afterResponse: { response in
      // 7 Ответ эквивалентен статусу 200(ок)
      XCTAssertEqual(response.status, .ok)

      // 8 Декодируем ответ в модель JSON (массив пользывателей)
      let users = try response.content.decode([User].self)
      
      // 9 Проверка того что было создано два пользывателя
        //добавление пользывателей в БД в нужном порядке
      XCTAssertEqual(users.count, 2)
      XCTAssertEqual(users[0].name, expectedName)
      XCTAssertEqual(users[0].username, expectedUsername)
      XCTAssertEqual(users[0].id, user.id)
    })
  } 
}


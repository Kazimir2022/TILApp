import Fluent
import Vapor

func routes(_ app: Application) throws {
  app.get { req async in
    "It works!"
  }
  
  app.get("hello") { req async -> String in
    "Hello, world!"
  }
  
  // 1
  app.post("api", "acronyms") { req -> EventLoopFuture<Acronym> in
    // 2
    let acronym = try req.content.decode(Acronym.self)//получаем модель из запроса при помощи декодирования
    // 3
    return acronym.save(on: req.db).map {// Сохраняем модель с помощью Fluent. Когда сохранение завершится, вы возвращаете модель внутри обработчика завершения для map(_:). Возвращает EventLoopFuture — в данном случае EventLoopFuture<Acronym>.Save(on:) возвращает EventLoopFuture<Void>, поэтому используйте map, чтобы вернуть аббревиатуру после завершения сохранения.
      // 4
      acronym
    }
  }
  
  // 1 Зарегистрируйте новый обработчик маршрута, который принимает GET-запрос, который возвращает EventLoopFuture<[Acronym]>, будущий массив Acronyms.
  /*
  let controller = AcronymsController()
  app.get("api", "acronyms", use: controller.getAllHandler)
  */
  // 1
  app.get("api", "acronyms", ":acronymID") {
    req -> EventLoopFuture<Acronym> in
    // 2 Получите переданный параметр с именем acronymID. Используйте find(_:on:) для запроса в базе данных аббревиатуру с этим идентификатором. Обратите внимание, что поскольку find(_:on:) принимает UUID в качестве первого параметра (поскольку тип идентификатора Acronym - UUID), get(_:) выводит возвращаемый тип как UUID. По умолчанию он возвращает String. Вы можете указать тип с помощью get(_:as:).
    Acronym.find(req.parameters.get("acronymID"), on: req.db)// find возвращает EventLoopFuture<Acronym?> так как его может не существовать в базе
    
    // 3 если указанный параметр отсутствует в БД то метод вернет EventLoopFuture с ошибкой
      .unwrap(or: Abort(.notFound))
  }
  
  
  // 1
  app.put("api", "acronyms", ":acronymID") {
    req -> EventLoopFuture<Acronym> in
    // 2
    let updatedAcronym = try req.content.decode(Acronym.self)
    return Acronym.find(
      req.parameters.get("acronymID"),
      on: req.db)
    .unwrap(or: Abort(.notFound)).flatMap { acronym in
      acronym.short = updatedAcronym.short
      acronym.long = updatedAcronym.long
      return acronym.save(on: req.db).map {
        debugPrint("ok")
        return acronym
        
      }
    }
  }
  
  
  /*
  app.put("api", "myApi") { req -> EventLoopFuture<Acronym> in
    
    let updateAcronym = try req.content.decode(Acronym.self)//получаем модель из запроса при помощи декодирования
    var u1: UUID = UUID(uuidString: "8cf81351c-3637-4e1d-be61-4b8f79ab6005")!
    return Acronym.find(u1, on: req.db).unwrap(or: Abort(.notFound)).flatMap { acr in
      acr.short = updateAcronym.short
      acr.long = updateAcronym.long
      return acr.save(on: req.db).map { acr
      }
    }
  }
  */
  // 1
  app.delete("api", "acronyms", ":acronymID") {
    req -> EventLoopFuture<HTTPStatus> in
    // фьючерс возвращает не модель а результат опирации, так как задача маршрута подразумевает удаление конкретной модели
    
    // 2
    Acronym.find(req.parameters.get("acronymID"), on: req.db)
      .unwrap(or: Abort(.notFound))// проверяет есть ли значение и делает его не опцинальным
    // 3
      .flatMap { acronym in
        // 4
        acronym.delete(on: req.db)
        // 5 Преобразуйте результат в ответ 204 No Content. Это сообщает клиенту, что запрос успешно выполнен, но нет содержимого для возврата.
          .transform(to: .noContent)
      }
  }
  
  // 1 не динамический парамет а обычный
  app.get("api", "acronyms", "search") {
    req -> EventLoopFuture<[Acronym]> in
    // 2 На сервер отправляем get запрос (URL с параметрами)
    //параметры извлекаем из запроса
    //добаляем строку запроса к URL(к последнему параметру) с именем term
    guard let searchTerm =
            req.query[String.self, at: "term"] else {
      throw Abort(.badRequest)
    }
    // 3 Запрос из базы данных всех значений + фильтр результата(свойство short БД соотв )
    /*
    return Acronym.query(on: req.db)
      .filter(\.$short == searchTerm)
      .all()
     */
    
    return Acronym.query(on: req.db).group(.or) { or in
      or.filter(\.$short == searchTerm)
      or.filter(\.$long == searchTerm)
    }.all()
  }
  
  // 1
  app.get("api", "acronyms", "first") {
    req -> EventLoopFuture<Acronym> in
    // 2
    Acronym.query(on: req.db)
      .first()
      .unwrap(or: Abort(.notFound))
  }
  
  // 1
  app.get("api", "acronyms", "sorted") {
    req -> EventLoopFuture<[Acronym]> in
    // 2
    Acronym.query(on: req.db)
      .sort(\.$short, .ascending)
      .all()
  }
  
  // 1
  let acronymsController = AcronymsController()
  // 2
  try app.register(collection: acronymsController)


  
}

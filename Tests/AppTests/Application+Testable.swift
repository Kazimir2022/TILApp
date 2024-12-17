//
//  Application+Testable.swift
//  TILApp
//
//  Created by Kazimir on 16.12.24.
//

import XCTVapor
import App

extension Application {
  static func testable() throws -> Application {
    let app = Application(.testing)
    try configure(app)
    
    try app.autoRevert().wait()
    try app.autoMigrate().wait()

    return app
  }
}

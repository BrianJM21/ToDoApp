//
//  TodoModel.swift
//  RealmMongoDB
//
//  Created by Brian Jiménez Moedano on 02/03/23.
//

import Foundation
import RealmSwift

class Todo: Object {
    
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var name: String = ""
    @Persisted var status: Bool
    @Persisted var ownerId: String
    
    convenience init(name: String, status: Bool = false, ownerId: String = "") {
        
        self.init()
        self.name = name
        self.status = status
        self.ownerId = ownerId
    }
}

enum Section {
    
    case done, pending
}

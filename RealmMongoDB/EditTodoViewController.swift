//
//  EditTodoViewController.swift
//  RealmMongoDB
//
//  Created by Brian Jiménez Moedano on 03/03/23.
//

import UIKit
import RealmSwift

class EditTodoViewController: UIViewController {
    
    var editingTodo = Todo()
    var indexPath = IndexPath()
    var realm: Realm!
    lazy var author: UILabel = {
        let label = UILabel()
        if editingTodo.ownerId.isEmpty {
            label.text = "Author: Local Device"
        } else if let currentUserId = App(id: "todoapp-fowrq").currentUser?.id {
            if currentUserId == editingTodo.ownerId {
                label.text = "Author: \(UserDefaults().string(forKey: editingTodo.ownerId) ?? editingTodo.ownerId)"
            } else {
                label.text = "Author: \(UserDefaults().string(forKey: editingTodo.ownerId) ?? editingTodo.ownerId) (Local Copy)"
            }
        } else {
            label.text = "Author: \(UserDefaults().string(forKey: editingTodo.ownerId) ?? editingTodo.ownerId) (Local Copy)"
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .boldSystemFont(ofSize: 20)
        return label
    }()
    lazy var name: UITextField = {
        let name = UITextField()
        name.text = editingTodo.name
        name.translatesAutoresizingMaskIntoConstraints = false
        return name
    }()
    lazy var status: UISwitch = {
        let status = UISwitch()
        status.isOn = editingTodo.status
        status.translatesAutoresizingMaskIntoConstraints = false
        return status
    }()
    var delegate: EditTodo?
    
    convenience init(editingTodo: Todo, indexPath: IndexPath, delegate: EditTodo, realm: Realm) {
        self.init()
        self.editingTodo = editingTodo
        self.indexPath = indexPath
        self.delegate = delegate
        self.realm = realm
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        // Las modificaciones que sufre el todo se reflejan directamente en la vista principal debido a que el todo con el que se trabaja en esta vista es una referencia fuerte al todo que se seleccionó en la vista principal. El mismo principio aplica para el delegado de esta vista, que es una referencia fuerte a la vista que la invoca.
        try! realm.write({
            editingTodo.name = name.text!
            editingTodo.status = status.isOn
        })
        delegate?.edit(editingTodo, at: indexPath)
    }
    
    func setupView() {
        view.backgroundColor = .systemBackground
        title = "Edit Todo"
        view.addSubview(status)
        status.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        status.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        view.addSubview(name)
        name.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        name.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        name.trailingAnchor.constraint(equalTo: status.leadingAnchor, constant: -10).isActive = true
        name.borderStyle = .roundedRect
        view.addSubview(author)
        author.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        author.bottomAnchor.constraint(equalTo: name.topAnchor, constant: -40).isActive = true
        author.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        author.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
    }
}

protocol EditTodo {
    
    func edit(_ todo: Todo, at indexPath: IndexPath)
}

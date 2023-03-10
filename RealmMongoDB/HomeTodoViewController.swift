//
//  ViewController.swift
//  RealmMongoDB
//
//  Created by Brian Jiménez Moedano on 21/02/23.
//

import UIKit
import RealmSwift

class HomeTodoViewController: UIViewController {
    
    lazy var todoTable: UITableView = {
        let table = UITableView(frame: view.bounds, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()
    lazy var loginButton: UIButton = {
        let button = UIButton(configuration: .filled())
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Login/SignUp", for: .normal)
        button.addTarget(self, action: #selector(loginAction), for: .touchDown)
        return button
    }()
    lazy var loading: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.isHidden = true
        return activityIndicator
    }()
    lazy var loadingTodos: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.isHidden = true
        activityIndicator.backgroundColor = .systemGray6
        activityIndicator.layer.cornerRadius = 3
        activityIndicator.frame.size.height = 500
        activityIndicator.frame.size.width = 500
        return activityIndicator
    }()
    lazy var connecting: UILabel = {
        let label = UILabel()
        label.text = "connecting..."
        label.backgroundColor = .systemGray6
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    lazy var todoTableDataSource: MyUITableViewDiffableDataSource = {
        let dataSource = MyUITableViewDiffableDataSource(tableView: todoTable) {
            
            [weak self] tableView, indexPath, todo in
            
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            config.text = todo.name
            if todo.ownerId.isEmpty {
                config.secondaryText = "Author: Local Device"
            } else if let currentUserId = self?.app.currentUser?.id {
                if currentUserId == todo.ownerId {
                    config.secondaryText = "Author: \(UserDefaults().string(forKey: todo.ownerId) ?? todo.ownerId)"
                } else {
                    config.secondaryText = "Author: \(UserDefaults().string(forKey: todo.ownerId) ?? todo.ownerId) (Local Copy)"
                }
            } else {
                config.secondaryText = "Author: \(UserDefaults().string(forKey: todo.ownerId) ?? todo.ownerId) (Local Copy)"
            }
            cell.contentConfiguration = config
            return cell
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Todo>()
        snapshot.appendSections([.done, .pending])
        let doneTodos = todos.where { $0.status == true }
        let pendingTodos = todos.where { $0.status == false }
        snapshot.appendItems(doneTodos.map({ todo in
            todo
        }), toSection: .done)
        snapshot.appendItems(pendingTodos.map({ todo in
            todo
        }), toSection: .pending)
        dataSource.apply(snapshot)
        dataSource.realm = realm
        dataSource.todos = todos
        return dataSource
    }()
    lazy var addTodoButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addTodoAction))
    var editingStatus = false
    // En un primer desarrollo, se modeló el objeto sin la propiedad "ownerId", posteriormente se agregó para integrarlo a una base de datos en la nube que identifique los todos de cierto usuario en particular. El bloque de migración sirve para identificar objetos desactualizados que necesitan conformar el más reciente diseño del objeto.
    lazy var realm = {
        let config = Realm.Configuration(
            schemaVersion: 2,
            migrationBlock: {
                migration, oldSchemaVersion in
                if  oldSchemaVersion < 2 {
                    migration.enumerateObjects(ofType: Todo.className()) {
                        oldObject, newObject in
                        newObject!["ownerId"] = ""
                    }
                }
            })
        Realm.Configuration.defaultConfiguration = config
        return try! Realm()
    }()
    var syncedRealm: Realm?
    lazy var todos = realm.objects(Todo.self)
    // El token de notificación se declara como propiedad de la clase para que la referencia no se pierda y quede "viva" durante toda la sesión de la App, observando y notificando modificaciones a la colección de objetos Todos
    lazy var notificationToken: NotificationToken? = nil
    let app = App(id: "todoapp-fowrq")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(todoTable)
        view.addSubview(loginButton)
        view.addSubview(loadingTodos)
        view.addSubview(connecting)
        loginButton.addSubview(loading)
        todoTable.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        todoTable.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        todoTable.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        todoTable.bottomAnchor.constraint(equalTo: loginButton.topAnchor).isActive = true
        loginButton.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        loginButton.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        loadingTodos.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        loadingTodos.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        connecting.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        connecting.topAnchor.constraint(equalTo: loadingTodos.bottomAnchor).isActive = true
        loading.centerXAnchor.constraint(equalTo: loginButton.centerXAnchor).isActive = true
        loading.centerYAnchor.constraint(equalTo: loginButton.centerYAnchor).isActive = true
        
        let guide = view.safeAreaLayoutGuide
        guide.bottomAnchor.constraint(equalToSystemSpacingBelow: loginButton.bottomAnchor, multiplier: 1).isActive = true
        todoTable.delegate = self
        title = "ToDo List"
        navigationItem.setRightBarButton(addTodoButton, animated: true)
        
        notificationToken = todos.observe { [weak self] changes in
            
            print("Hay cambios en el Realm")
            switch changes {
            case .initial:
                // Results are now populated and can be accessed without blocking the UI
                print("INITIAL")
                if let user = self?.app.currentUser {
                    self?.userLoggedIn(user.id)
                }
            case .update(_, let deletions, let insertions, let modifications):
                // Query results have changed
                // Always apply updates in the following order: deletions, insertions, then modifications.
                // Handling insertions before deletions may result in unexpected behavior.
                print("Deleted indices: ", deletions)
                print("Inserted indices: ", insertions)
                print("Modified modifications: ", modifications)
                guard let syncedRealm = self?.syncedRealm else { return }
                if !modifications.isEmpty {
                    let todoEdited = self!.todos[modifications.first!]
                    if let todoToEdit = syncedRealm.objects(Todo.self).where({ $0._id == todoEdited._id }).first {
                        try! syncedRealm.write({
                            todoToEdit.name = todoEdited.name
                            todoToEdit.status = todoEdited.status
                        })
                    }
                }
            case .error(let error):
                // An error occurred while opening the Realm file on the background worker thread
                fatalError("\(error)")
            }
        }
        
        todoTableDataSource.applySnapshotUsingReloadData(todoTableDataSource.snapshot())
    }
    
    @objc func addTodoAction() {
        
        //se instancia el todo nuevo para que al agregarse a la tabla y al realm, tengan la misma referencia a memoria
        let todoToAdd = Todo(name: "new toDo", ownerId: app.currentUser?.id ?? "")
        var snapshot = todoTableDataSource.snapshot()
        snapshot.appendItems([todoToAdd], toSection: .pending)
        todoTableDataSource.apply(snapshot)
        try! realm.write {
            realm.add(todoToAdd)
        }
        if let syncedRealm = syncedRealm {
            try! syncedRealm.write {
                syncedRealm.create(Todo.self, value: todoToAdd)
            }
        }
    }
    
    @objc func loginAction() {
        present(LoginTodoViewController(delegate: self), animated: true)
    }
    
    @objc func logoutAction() {
        loading.startAnimating()
        loading.isHidden = false
        loginButton.isEnabled = false
        let currentUserId = app.currentUser!.id
        app.currentUser?.logOut { [weak self] error in
            if let error = error {
                print(error.localizedDescription)
            }
            DispatchQueue.main.async {
                self?.loading.stopAnimating()
                self?.loading.isHidden = true
                self?.loginButton.isEnabled = true
                self?.title = "ToDo List"
                self?.loginButton.configuration?.background.backgroundColor = .link
                self?.loginButton.setTitle("Login/SignUp", for: .normal)
                self?.loginButton.removeTarget(self, action: #selector(self?.logoutAction), for: .touchDown)
                self?.loginButton.addTarget(self, action: #selector(self?.loginAction), for: .touchDown)
                self?.syncedRealm = nil
                self?.todoTableDataSource.syncedRealm = nil
                let cleanTodosAlert = UIAlertController(title: "Successfully Logout", message: "Do you want to preserve local copies of the previous user's ToDos?", preferredStyle: .actionSheet)
                let preserveAction = UIAlertAction(title: "Preserve", style: .cancel) { _ in
                    if let snapshot = self?.todoTableDataSource.snapshot() {
                        self?.todoTableDataSource.applySnapshotUsingReloadData(snapshot)
                    }
                }
                let cleanAction = UIAlertAction(title: "Clean", style: .destructive) {
                    _ in
                    if let todosToClean = self?.todos.where({ $0.ownerId == currentUserId }) {
                        var snapshot = self?.todoTableDataSource.snapshot()
                        snapshot!.deleteItems(todosToClean.map({ todo in
                            todo
                        }))
                        self?.todoTableDataSource.apply(snapshot!)
                        try! self?.realm.write({
                            self?.realm.delete(todosToClean)
                        })
                    }
                }
                cleanTodosAlert.addAction(preserveAction)
                cleanTodosAlert.addAction(cleanAction)
                self?.present(cleanTodosAlert, animated: true)
            }
        }
    }
}

class MyUITableViewDiffableDataSource: UITableViewDiffableDataSource<Section, Todo> {
    
    var realm: Realm! = nil
    var syncedRealm: Realm! = nil
    var todos: Results<Todo>!
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        
        case 0 : return "✅ DONE"
        case 1 : return "🕒 PENDING"
        default : return "UNKNOWN"
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            let todoToDelete = self.itemIdentifier(for: indexPath)!
            let deletedId = todoToDelete._id
            var snapshot = self.snapshot()
            snapshot.deleteItems([todoToDelete])
            self.apply(snapshot)
            try! realm.write({
                realm.delete(todos.where({ $0._id == todoToDelete._id }))
            })
            if let syncedRealm = self.syncedRealm {
                if let todoDeleted = syncedRealm.objects(Todo.self).where({ $0._id == deletedId }).first {
                    try! syncedRealm.write({
                        syncedRealm.delete(todoDeleted)
                    })
                }
            }
        }
    }
}

extension HomeTodoViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        editingStatus = todoTableDataSource.itemIdentifier(for: indexPath)!.status
        // Se instancia el EditTodoViewController con una referencia fuerte del todo seleccionado, lo mismo para el delegado y el realm.
        navigationController?.pushViewController(EditTodoViewController(editingTodo: todoTableDataSource.itemIdentifier(for: indexPath)!, indexPath: indexPath, delegate: self, realm: realm), animated: true)
    }
}

extension HomeTodoViewController: EditTodo {
    
    func edit(_ todo: Todo, at indexPath: IndexPath) {
        
        var snapshot = todoTableDataSource.snapshot()
        if editingStatus != todo.status {
            snapshot.deleteItems([todoTableDataSource.itemIdentifier(for: indexPath)!])
            snapshot.appendItems([todo], toSection: todo.status ? .done : .pending)
        }
        todoTableDataSource.applySnapshotUsingReloadData(snapshot)
    }
}

extension HomeTodoViewController: UserLoggedIn {
    
    func userLoggedIn(_ userId: String) {
        title = "\(UserDefaults().string(forKey: userId) ?? userId)'s ToDo List"
        loginButton.configuration?.background.backgroundColor = .red
        loginButton.setTitle("Logout", for: .normal)
        loginButton.removeTarget(self, action: #selector(loginAction), for: .touchDown)
        loginButton.addTarget(self, action: #selector(logoutAction), for: .touchDown)
        loadingTodos.startAnimating()
        loadingTodos.isHidden = false
        connecting.isHidden = false
        Task {
            do {
                var config = app.currentUser!.flexibleSyncConfiguration()
                    // Pass object types to the Flexible Sync configuration
                    // as a temporary workaround for not being able to add a
                    // complete schema for a Flexible Sync app.
                config.objectTypes = [Todo.self]
                let realm = try await Realm(configuration: config, downloadBeforeOpen: .always)
                    // You must add at least one subscription to read and write from a Flexible Sync realm
                    let subscriptions = realm.subscriptions
                    try await subscriptions.update {
                        subscriptions.append(
                            QuerySubscription<Todo> {
                                $0.ownerId == self.app.currentUser!.id
                            })
                    }
                let syncedTodos = realm.objects(Todo.self)
                var snapshot = todoTableDataSource.snapshot()
                for syncedTodo in syncedTodos {
                    if !todos.isEmpty {
                        var alreadyExists = false
                        for todo in todos {
                            if syncedTodo._id == todo._id {
                                alreadyExists = true
                                break
                            }
                        }
                        if alreadyExists {
                            snapshot.deleteItems([todos.where({ $0._id == syncedTodo._id }).first!])
                            try! self.realm.write({
                                todos.where({ $0._id == syncedTodo._id }).first!.name = syncedTodo.name
                                todos.where({ $0._id == syncedTodo._id }).first!.status = syncedTodo.status
                            })
                        } else {
                            try! self.realm.write({
                                self.realm.create(Todo.self, value: syncedTodo)
                            })
                        }
                        if syncedTodo.status {
                            snapshot.appendItems([todos.where({ $0._id == syncedTodo._id }).first!], toSection: .done)
                        } else {
                            snapshot.appendItems([todos.where({ $0._id == syncedTodo._id }).first!], toSection: .pending)
                        }
                    } else {
                        let todo = Todo(value: syncedTodo)
                        try! self.realm.write({
                            self.realm.add(todo)
                        })
                        if todo.status {
                            snapshot.appendItems([todo], toSection: .done)
                        } else {
                            snapshot.appendItems([todo], toSection: .pending)
                        }
                    }
                }
                if syncedTodos.count != todos.where({ $0.ownerId == userId }).count {
                    var missingTodo = true
                    for todo in todos.where({ $0.ownerId == userId }) {
                        for syncedTodo in syncedTodos {
                            if todo._id == syncedTodo._id {
                                missingTodo = false
                                break
                            }
                            missingTodo = true
                        }
                        if missingTodo {
                            try! realm.write({
                                realm.create(Todo.self, value: todo)
                            })
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.todoTableDataSource.applySnapshotUsingReloadData(snapshot)
                }
                self.syncedRealm = realm
                todoTableDataSource.syncedRealm = realm
                loadingTodos.stopAnimating()
                loadingTodos.isHidden = true
                connecting.isHidden = true
                if todos.where({ $0.ownerId == "" }).count > 0 {
                    let importTodosAlert = UIAlertController(title: "Successfully Login", message: "Do you want to import local ToDos to actual user's list?", preferredStyle: .actionSheet)
                    let keepLocalAction = UIAlertAction(title: "Keep them local", style: .cancel)
                    let importAction = UIAlertAction(title: "Import", style: .destructive) {
                        [weak self] _ in
                        guard let todos = self?.todos else {return}
                        for localTodo in todos.where({ $0.ownerId == "" }) {
                            try! self?.realm.write({
                                localTodo.ownerId = userId
                            })
                            try! realm.write({
                                realm.create(Todo.self, value: localTodo)
                            })
                        }
                        DispatchQueue.main.async {
                            if let snapshot = self?.todoTableDataSource.snapshot() {
                                self?.todoTableDataSource.applySnapshotUsingReloadData(snapshot)
                            }
                        }
                    }
                    importTodosAlert.addAction(keepLocalAction)
                    importTodosAlert.addAction(importAction)
                    present(importTodosAlert, animated: true)
                }
                } catch {
                    print("Error opening realm: \(error.localizedDescription)")
                    loadingTodos.stopAnimating()
                    loadingTodos.isHidden = true
                    connecting.isHidden = true
                }
        }
    }
}

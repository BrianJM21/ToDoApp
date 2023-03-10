//
//  LoginTodoViewController.swift
//  RealmMongoDB
//
//  Created by Brian Jiménez Moedano on 07/03/23.
//

import RealmSwift
import UIKit

class LoginTodoViewController: UIViewController {
    
    lazy var viewTitle: UILabel = {
        let label = UILabel()
        label.text = "Login or SignUp to access cloud persistent service."
        label.numberOfLines = 0
        label.font = .boldSystemFont(ofSize: 20)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    lazy var email: UITextField = {
       let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "enter user name (e.g.: ToDoer)"
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    lazy var password: UITextField = {
       let textField = UITextField()
        textField.borderStyle = .roundedRect
        textField.placeholder = "enter password: *******"
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    lazy var loginSetup: UIButton = {
        let button = UIButton(configuration: .filled())
        button.setTitle("Login/SignUp", for: .normal)
        button.addTarget(self, action: #selector(loginSetupAction), for: .touchDown)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    lazy var loading: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.isHidden = true
        return activityIndicator
    }()
    lazy var tap: UITapGestureRecognizer = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        return gesture
    }()
    lazy var error: UILabel = {
        let label = UILabel()
        label.tintColor = .placeholderText
        label.font = .boldSystemFont(ofSize: 10)
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    let app = App(id: "todoapp-fowrq")
    lazy var client = app.emailPasswordAuth
    var delegate: UserLoggedIn!
    
    convenience init(delegate: UserLoggedIn) {
        self.init()
        
        self.delegate = delegate
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addGestureRecognizer(tap)
        view.backgroundColor = .systemBackground
        view.addSubview(viewTitle)
        view.addSubview(email)
        view.addSubview(password)
        view.addSubview(loginSetup)
        view.addSubview(error)
        loginSetup.addSubview(loading)
        viewTitle.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        viewTitle.topAnchor.constraint(equalTo: view.topAnchor, constant: 30).isActive = true
        viewTitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        viewTitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        email.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        email.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100).isActive = true
        email.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        email.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        password.topAnchor.constraint(equalTo: email.bottomAnchor, constant: 20).isActive = true
        password.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        password.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
        loginSetup.topAnchor.constraint(equalTo: password.bottomAnchor, constant: 40).isActive = true
        loginSetup.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        loading.centerXAnchor.constraint(equalTo: loginSetup.centerXAnchor).isActive = true
        loading.centerYAnchor.constraint(equalTo: loginSetup.centerYAnchor).isActive = true
        error.topAnchor.constraint(equalTo: loginSetup.bottomAnchor, constant: 40).isActive = true
        error.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20).isActive = true
        error.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20).isActive = true
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc func loginSetupAction() {
        if email.text!.isEmpty || password.text!.isEmpty {
            error.isHidden = false
            error.text = "An error ocurred while trying to Login user. Please, check email or password fields are not empty."
        } else {
            error.isHidden = true
            loginSetup.isEnabled = false
            loading.isHidden = false
            loading.startAnimating()
            login(email: email.text!, password: password.text!)
        }
    }
    
    // Remember to dispatch to main if you are doing anything on the UI thread
    func signUp(email: String, password: String) {
        client.registerUser(email: email, password: password) { [weak self] error in
            guard error == nil else {
                print("Failed to register: \(error!.localizedDescription)")
                DispatchQueue.main.async {
                    self?.loginSetup.isEnabled = true
                    self?.loading.stopAnimating()
                    self?.loading.isHidden = true
                    self?.error.isHidden = false
                    if error!.localizedDescription.contains("A data connection is not currently allowed.") || error!.localizedDescription.contains("The Internet connection appears to be offline.") {
                        self?.error.text = "An error ocurred while trying to SignUp user. Please, check your Internet connection and try again."
                    }
                    if error!.localizedDescription.contains("password must be between 6 and 128 characters") {
                        self?.error.text = "An error ocurred while trying to SignUp user. Please, remember that password must be between 6 and 128 characters"
                    }
                }
                return
            }
            // Registering just registers. You can now log in.
            print("Successfully registered user.")
            self?.login(email: email, password: password)
        }
    }
    
    // Remember to dispatch to main if you are doing anything on the UI thread
    func login(email: String, password: String) {
        app.login(credentials: Credentials.emailPassword(email: email, password: password)) { [weak self] result in
            switch result {
            case .failure(let error):
                print("Login failed: \(error.localizedDescription)")
                let actionSheetAlert = UIAlertController(title: "Login failed...", message: "Do you wish to SignUp with actual credentials?", preferredStyle: .actionSheet)
                let signup = UIAlertAction(title: "SignUp", style: .destructive) { [weak self] _ in
                    self?.signUp(email: email, password: password)
                }
                let cancel = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.loginSetup.isEnabled = true
                        self?.loading.stopAnimating()
                        self?.loading.isHidden = true
                    }
                }
                actionSheetAlert.addAction(signup)
                actionSheetAlert.addAction(cancel)
                DispatchQueue.main.async {
                    self?.present(actionSheetAlert, animated: true)
                }
            case .success(let user):
                print("Successfully logged in as user \(email) - \(user)")
                UserDefaults().set(email, forKey: user.id)
                DispatchQueue.main.async {
                    self?.dismiss(animated: true)
                    self?.delegate.userLoggedIn(user.id)
                }
            }
        }

    }
}

protocol UserLoggedIn {
    
    func userLoggedIn(_ userId: String)
}

import UIKit
import StoreKit

class SettingsViewController: UIViewController {
    
    // MARK: - Properties
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
    // 設定項目の定義
    private struct Section {
        let title: String
        let items: [SettingItem]
    }
    
    private struct SettingItem {
        let title: String
        let description: String?
        let icon: UIImage?
        let action: () -> Void
    }
    
    private var sections: [Section] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupData()
        setupUI()
        
        // タイトルを設定
        title = "設定"
        
        // ナビゲーションバーの設定
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "ホーム",
            style: .plain,
            target: self,
            action: #selector(backToHome)
        )
    }
    
    @objc private func backToHome() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = UIColor(red: 242/255, green: 244/255, blue: 248/255, alpha: 1.0) // #F2F4F8
        
        // テーブルビューの設定
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        
        view.addSubview(tableView)
        
        // オートレイアウト制約
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupData() {
        // アプリ情報セクション
        let appInfoSection = Section(title: "アプリ情報", items: [
            SettingItem(
                title: "バージョン情報",
                description: "バージョン情報を表示します",
                icon: UIImage(systemName: "info.circle"),
                action: { self.showVersionInfo() }
            ),
            SettingItem(
                title: "使い方",
                description: "アプリの使い方を説明します",
                icon: UIImage(systemName: "questionmark.circle"),
                action: { self.showHowToUse() }
            )
        ])
        
        // 保存設定セクション
        let saveSettingsSection = Section(title: "保存設定", items: [
            SettingItem(
                title: "保存先フォルダ",
                description: "PDFの保存先フォルダについて説明します",
                icon: UIImage(systemName: "folder"),
                action: { self.showSaveLocation() }
            ),
            SettingItem(
                title: "保存したファイルを見る",
                description: nil,
                icon: UIImage(systemName: "doc"),
                action: { self.openFilesApp() }
            )
        ])
        
        // 開発者情報セクション
        let developerSection = Section(title: "開発者情報", items: [
            SettingItem(
                title: "製品ホームページ",
                description: "開発元のウェブサイトを表示します",
                icon: UIImage(systemName: "safari"),
                action: { self.openWebsite() }
            ),
            SettingItem(
                title: "レビュー / 評価",
                description: "App Storeでアプリを評価します",
                icon: UIImage(systemName: "star"),
                action: { self.rateApp() }
            )
        ])
        
        // その他セクション
        let otherSection = Section(title: "その他", items: [
            SettingItem(
                title: "お問い合わせ",
                description: "開発者へのお問い合わせ方法を表示します",
                icon: UIImage(systemName: "envelope"),
                action: { self.showContactInfo() }
            )
        ])
        
        sections = [appInfoSection, saveSettingsSection, developerSection, otherSection]
    }
    
    // MARK: - Actions
    
    // バージョン情報を表示
    private func showVersionInfo() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        let alert = UIAlertController(
            title: "バージョン情報",
            message: "PhotoIt\n\nバージョン: \(appVersion)\nビルド: \(buildNumber)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // 使い方を表示
    private func showHowToUse() {
        let alert = UIAlertController(
            title: "使い方",
            message: "1. ホーム画面で「Take Photo」または「Select Photo」をタップ\n2. 写真に付箋を追加\n3. 付箋をタップしてテキストを入力\n4. 完了したら「Save」ボタンをタップ\n5. PDFが「PhotoIt」フォルダに保存されます",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // 保存先を表示
    private func showSaveLocation() {
        let alert = UIAlertController(
            title: "保存先フォルダ",
            message: "PDFは以下の場所に保存されます：\n\n「Files」アプリ > 「この iPhone 内」 > 「オンマイデバイス」 > 「PhotoIt」フォルダ\n\nファイル名形式：\nPhotoIt_YYYYMMDD_HHMMSS.pdf",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // ファイルアプリを開く
    private func openFilesApp() {
        if let url = URL(string: "shareddocuments://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                showAlert(title: "エラー", message: "ファイルアプリを開けませんでした。")
            }
        }
    }
    
    // SafetyLabのウェブサイトを開く
    private func openWebsite() {
        if let url = URL(string: "https://safetylab-jp.com/") {
            UIApplication.shared.open(url)
        }
    }
    
    // アプリのレビューを表示
    private func rateApp() {
        if #available(iOS 10.3, *) {
            SKStoreReviewController.requestReview()
        } else {
            // App Storeのレビューページを開く（実際のアプリIDに置き換える必要があります）
            if let url = URL(string: "https://apps.apple.com/app/idXXXXXXXXXX?action=write-review") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    // お問い合わせ情報を表示
    private func showContactInfo() {
        let emailAddress = "support@safetylab-jp.com"
        
        let alert = UIAlertController(
            title: "お問い合わせ",
            message: "以下のメールアドレスにお問い合わせください：\n\n\(emailAddress)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // 汎用アラート表示
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // サブタイトルスタイルのセルを作成
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "SettingsCell")
        let item = sections[indexPath.section].items[indexPath.row]
        
        // 通常のセル表示
        if #available(iOS 14.0, *) {
            var content = cell.defaultContentConfiguration()
            content.text = item.title
            content.secondaryText = item.description
            content.image = item.icon
            cell.contentConfiguration = content
        } else {
            // iOS 13以前の設定
            cell.textLabel?.text = item.title
            cell.detailTextLabel?.text = item.description
            cell.imageView?.image = item.icon
        }
        
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // 選択されたアイテムのアクションを実行
        let item = sections[indexPath.section].items[indexPath.row]
        item.action()
    }
}


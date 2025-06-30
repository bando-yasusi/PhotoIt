import UIKit
import Photos
import AVFoundation

class MainViewController: UIViewController {
    
    // MARK: - IBOutlets
    @IBOutlet weak var takePhotoButton: UIButton!
    @IBOutlet weak var selectPhotoButton: UIButton!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // 戻るボタンのテキストを「Home」に設定
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "Home", style: .plain, target: nil, action: nil)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "PhotoIt"
        
        // ボタンのスタイル設定
        takePhotoButton.layer.cornerRadius = 10
        takePhotoButton.backgroundColor = UIColor.systemBlue
        takePhotoButton.setTitleColor(.white, for: .normal)
        
        selectPhotoButton.layer.cornerRadius = 10
        selectPhotoButton.backgroundColor = UIColor.systemGreen
        selectPhotoButton.setTitleColor(.white, for: .normal)
    }
    
    // MARK: - IBActions
    @IBAction func takePhotoButtonTapped(_ sender: UIButton) {
        checkCameraPermission()
    }
    
    @IBAction func selectPhotoButtonTapped(_ sender: UIButton) {
        checkPhotoLibraryPermission()
    }
    
    @IBAction func setting(_ sender: Any) {
        // コードで直接SettingsViewControllerをインスタンス化して表示
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
    
    // MARK: - Permission Handling
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.presentCamera()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert(for: "カメラ")
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermission() {
        if #available(iOS 14, *) {
            // iOS 14以降では、アクセスレベルを指定できる
            switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
            case .authorized, .limited:
                presentPhotoLibrary()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
                    if status == .authorized || status == .limited {
                        DispatchQueue.main.async {
                            self?.presentPhotoLibrary()
                        }
                    }
                }
            case .denied, .restricted:
                showPermissionAlert(for: "フォトライブラリ")
            @unknown default:
                break
            }
        } else {
            // iOS 14未満の場合は従来の方法を使用
            switch PHPhotoLibrary.authorizationStatus() {
            case .authorized:
                presentPhotoLibrary()
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { [weak self] status in
                    if status == .authorized {
                        DispatchQueue.main.async {
                            self?.presentPhotoLibrary()
                        }
                    }
                }
            case .denied, .restricted:
                showPermissionAlert(for: "フォトライブラリ")
            @unknown default:
                break
            }
        }
    }
    
    private func showPermissionAlert(for type: String) {
        let alert = UIAlertController(
            title: "\(type)へのアクセスが拒否されています",
            message: "設定アプリから\(type)へのアクセスを許可してください",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "設定を開く", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Camera & Photo Library
    private func presentCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            present(picker, animated: true)
        }
    }
    
    private func presentPhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            present(picker, animated: true)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension MainViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            // NavigationControllerを使用して編集画面に遷移
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let editVC = storyboard.instantiateViewController(withIdentifier: "EditPhotoViewController") as? EditPhotoViewController {
                editVC.selectedImage = image
                navigationController?.pushViewController(editVC, animated: true)
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}


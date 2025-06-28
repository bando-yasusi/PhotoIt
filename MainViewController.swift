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
    
    // MARK: - Permission Handling
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentCamera()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert(
                title: "カメラへのアクセスが拒否されています",
                message: "設定アプリからカメラへのアクセスを許可してください"
            )
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermission() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized, .limited:
            presentPhotoLibrary()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        self?.presentPhotoLibrary()
                    }
                }
            }
        case .denied, .restricted:
            showPermissionAlert(
                title: "フォトライブラリへのアクセスが拒否されています",
                message: "設定アプリからフォトライブラリへのアクセスを許可してください"
            )
        @unknown default:
            break
        }
    }
    
    private func showPermissionAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "設定を開く", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Camera & Photo Library
    private func presentCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .camera
            imagePicker.allowsEditing = false
            present(imagePicker, animated: true)
        } else {
            let alert = UIAlertController(
                title: "カメラが利用できません",
                message: "このデバイスではカメラが使用できません",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    private func presentPhotoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = .photoLibrary
            imagePicker.allowsEditing = false
            present(imagePicker, animated: true)
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

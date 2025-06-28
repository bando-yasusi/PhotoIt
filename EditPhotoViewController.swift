import UIKit
import PDFKit

class EditPhotoViewController: UIViewController, ArrowStickyNoteViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: - Properties
    var selectedImage: UIImage?
    private var stickyNote: ArrowStickyNoteView!
    private var isEditingText = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardNotifications()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // レイアウト完了後に付箋の位置を調整
        if stickyNote != nil && stickyNote.superview == nil {
            setupStickyNote()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 画面表示後、少し遅延させてからテキストビューにフォーカスを当てる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            // テキストビューを編集可能にする
            self.stickyNote.textView.becomeFirstResponder()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        title = "編集"
        
        // 画像を表示
        imageView.image = selectedImage
        imageView.contentMode = .scaleAspectFit
        
        // ボタンのスタイル設定
        saveButton.layer.cornerRadius = 10
        saveButton.backgroundColor = UIColor.systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        
        cancelButton.layer.cornerRadius = 10
        cancelButton.backgroundColor = UIColor.systemRed
        cancelButton.setTitleColor(.white, for: .normal)
        
        // 付箋を追加
        setupStickyNote()
    }
    
    // 付箋のセットアップ
    private func setupStickyNote() {
        // 付箋のサイズと位置を設定
        let stickyNoteSize = CGSize(width: 200, height: 120)
        let stickyNoteFrame = CGRect(
            x: (imageView.bounds.width - stickyNoteSize.width) / 2,
            y: (imageView.bounds.height - stickyNoteSize.height) / 2,
            width: stickyNoteSize.width,
            height: stickyNoteSize.height
        )
        
        // 付箋を作成
        stickyNote = ArrowStickyNoteView(frame: stickyNoteFrame)
        stickyNote.text = "テキストを入力"
        stickyNote.delegate = self
        
        // 移動用のパンジェスチャーを追加
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        stickyNote.addGestureRecognizer(panGesture)
        
        // 回転用のジェスチャーを追加
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        stickyNote.addGestureRecognizer(rotationGesture)
        
        // 画像ビューに付箋を追加
        imageView.addSubview(stickyNote)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        if isEditingText, let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
            
            // コンテンツを上にスクロールしてキーボードに隠れないようにする
            var viewFrame = view.frame
            viewFrame.size.height -= keyboardSize.height
            
            if stickyNote != nil {
                let stickyNoteFrame = stickyNote.convert(stickyNote.bounds, to: view)
                if !viewFrame.contains(stickyNoteFrame) {
                    UIView.animate(withDuration: 0.3) {
                        self.view.frame.origin.y -= keyboardSize.height / 2
                    }
                }
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        if isEditingText {
            UIView.animate(withDuration: 0.3) {
                self.view.frame.origin.y = 0
            }
        }
    }
    
    // MARK: - IBActions
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        generateAndSavePDF()
    }
    
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let stickyView = gesture.view as? ArrowStickyNoteView, stickyView == stickyNote else { return }
        
        let translation = gesture.translation(in: imageView)
        stickyView.center = CGPoint(
            x: stickyView.center.x + translation.x,
            y: stickyView.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: imageView)
    }
    
    @objc private func handleRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        guard let stickyView = gesture.view as? ArrowStickyNoteView, stickyView == stickyNote else { return }
        
        if gesture.state == .changed {
            stickyView.transform = stickyView.transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
            
            // テキストの向きを調整
            let currentRotation = atan2(stickyView.transform.b, stickyView.transform.a)
            stickyView.adjustTextRotation(for: currentRotation)
        }
    }
    
    // MARK: - ArrowStickyNoteViewDelegate
    func stickyNoteDidBeginEditing(_ stickyNote: ArrowStickyNoteView) {
        isEditingText = true
    }
    
    func stickyNoteDidEndEditing(_ stickyNote: ArrowStickyNoteView) {
        isEditingText = false
    }
    
    // MARK: - PDF Generation
    private func generateAndSavePDF() {
        // 現在の画面を画像としてキャプチャ
        UIGraphicsBeginImageContextWithOptions(imageView.bounds.size, false, 0.0)
        imageView.drawHierarchy(in: imageView.bounds, afterScreenUpdates: true)
        guard let capturedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return
        }
        UIGraphicsEndImageContext()
        
        // PDFを生成
        let pdfData = NSMutableData()
        let pdfPageBounds = CGRect(x: 0, y: 0, width: capturedImage.size.width, height: capturedImage.size.height)
        
        UIGraphicsBeginPDFContextToData(pdfData, pdfPageBounds, nil)
        UIGraphicsBeginPDFPage()
        
        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        
        // PDFに画像を描画
        context.translateBy(x: 0, y: pdfPageBounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.draw(capturedImage.cgImage!, in: pdfPageBounds)
        
        context.restoreGState()
        UIGraphicsEndPDFContext()
        
        // PDFを保存または共有
        showShareSheet(with: pdfData as Data)
    }
    
    private func showShareSheet(with pdfData: Data) {
        // 一時ファイルとしてPDFを保存
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "PhotoIt_\(Date().timeIntervalSince1970).pdf"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            
            // 共有シートを表示
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            activityVC.completionWithItemsHandler = { _, completed, _, _ in
                if completed {
                    // 保存成功のアラートを表示
                    let alert = UIAlertController(
                        title: "保存完了",
                        message: "PDFが正常に保存されました",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        self.navigationController?.popViewController(animated: true)
                    })
                    self.present(alert, animated: true)
                }
            }
            
            present(activityVC, animated: true)
        } catch {
            print("PDFの保存に失敗しました: \(error)")
            
            // エラーアラートを表示
            let alert = UIAlertController(
                title: "エラー",
                message: "PDFの保存に失敗しました",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}

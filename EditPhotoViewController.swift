import UIKit
import PDFKit

class EditPhotoViewController: UIViewController, UIGestureRecognizerDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: - Properties
    var selectedImage: UIImage?
    private var stickyNote: UIView!
    private var stickyImageView: UIImageView!
    private var textView: UITextView!
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
        if stickyNote == nil || stickyNote.superview == nil {
            setupStickyNote()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // 画面表示後、少し遅延させてからテキストビューにフォーカスを当てる
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            // テキストビューを編集可能にする
            self.textView.becomeFirstResponder()
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
        imageView.isUserInteractionEnabled = true // ジェスチャー認識のために必須
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
        
        // 付箋のベースビューを作成
        stickyNote = UIView(frame: stickyNoteFrame)
        stickyNote.isUserInteractionEnabled = true
        
        // 付箋の画像ビューを作成
        stickyImageView = UIImageView(frame: stickyNote.bounds)
        stickyImageView.image = UIImage(named: "arrow_left_yellow")
        stickyImageView.contentMode = .scaleAspectFit
        stickyImageView.isUserInteractionEnabled = false
        stickyNote.addSubview(stickyImageView)
        
        // テキストビューを作成
        // 左側により大きな余白を設定して矢印からはみ出さないようにする
        let paddingLeft: CGFloat = 25  // 左側の余白を増やす
        let paddingRight: CGFloat = 10
        let paddingVertical: CGFloat = 10
        
        // 左右非対称な余白を設定したフレームを作成
        let textViewFrame = CGRect(
            x: stickyNote.bounds.origin.x + paddingLeft,
            y: stickyNote.bounds.origin.y + paddingVertical,
            width: stickyNote.bounds.width - paddingLeft - paddingRight,
            height: stickyNote.bounds.height - (paddingVertical * 2)
        )
        
        textView = UITextView(frame: textViewFrame)
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.textAlignment = .center
        textView.textColor = .lightGray
        textView.text = "テキストを入力"
        textView.delegate = self
        textView.returnKeyType = .done
        textView.isScrollEnabled = false
        stickyNote.addSubview(textView)
        
        // 移動用のパンジェスチャーを追加
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        panGesture.cancelsTouchesInView = false  // タッチイベントをキャンセルしない
        stickyNote.addGestureRecognizer(panGesture)
        
        // 回転用のジェスチャーを追加
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        rotationGesture.delegate = self
        rotationGesture.cancelsTouchesInView = false  // タッチイベントをキャンセルしない
        stickyNote.addGestureRecognizer(rotationGesture)
        
        // タップジェスチャーを追加（テキスト編集のため）
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        tapGesture.delegate = self
        tapGesture.cancelsTouchesInView = false
        stickyNote.addGestureRecognizer(tapGesture)
        
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
            // コンテンツを上にスクロールしてキーボードに隠れないようにする
            var viewFrame = view.frame
            viewFrame.size.height -= keyboardSize.height
            
            if stickyNote != nil {
                let stickyNoteFrame = stickyNote.convert(stickyNote.bounds, to: view)
                
                // 付箋がキーボードに隠れる場合は、スクロールして表示する
                if stickyNoteFrame.maxY > viewFrame.height {
                    let yOffset = stickyNoteFrame.maxY - viewFrame.height + 20 // 20pxの余白
                    imageView.transform = CGAffineTransform(translationX: 0, y: -yOffset)
                }
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        // キーボードが隠れたら元の位置に戻す
        imageView.transform = .identity
    }
    
    // MARK: - Actions
    @IBAction func cancelButtonTapped(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }
    
    @IBAction func saveButtonTapped(_ sender: UIButton) {
        // キーボードを閉じる
        view.endEditing(true)
        
        // PDFを生成して共有
        generateAndSavePDF()
    }
    
    // MARK: - Gesture Handlers
    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let stickyView = gesture.view, stickyView == stickyNote else { return }
        
        // 常に移動できるようにする
        let translation = gesture.translation(in: imageView)
        stickyView.center = CGPoint(
            x: stickyView.center.x + translation.x,
            y: stickyView.center.y + translation.y
        )
        gesture.setTranslation(.zero, in: imageView)
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        // タップしたときにテキストビューにフォーカスを当てる
        if !textView.isFirstResponder {
            textView.becomeFirstResponder()
        }
    }
    
    @objc private func handleRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        guard let stickyView = gesture.view, stickyView == stickyNote else { return }
        
        if gesture.state == .changed {
            stickyView.transform = stickyView.transform.rotated(by: gesture.rotation)
            gesture.rotation = 0
            
            // テキストの向きを調整
            adjustTextRotation()
        }
    }
    
    // テキストの向きを調整
    private func adjustTextRotation() {
        let currentRotation = atan2(stickyNote.transform.b, stickyNote.transform.a)
        let normalizedRotation = ((currentRotation * 180 / .pi) + 360).truncatingRemainder(dividingBy: 360)
        
        if (normalizedRotation > 90 && normalizedRotation < 270) {
            // 上下逆さまのとき、テキストを180度回転
            textView.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            // 通常の向き
            textView.transform = .identity
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // パンジェスチャーとローテーションジェスチャーは常に受け付ける
        if gestureRecognizer is UIPanGestureRecognizer || gestureRecognizer is UIRotationGestureRecognizer {
            return true
        }
        
        // タップジェスチャーの場合、テキストビューが編集中なら無視
        if gestureRecognizer is UITapGestureRecognizer && textView.isFirstResponder {
            return false
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 複数のジェスチャーを同時に認識できるようにする
        return true
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
        
        capturedImage.draw(in: pdfPageBounds)
        
        UIGraphicsEndPDFContext()
        
        // 一時ファイルとしてPDFを保存
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("photo_with_notes.pdf")
        try? pdfData.write(to: tempURL)
        
        // 共有シートを表示
        let activityViewController = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        present(activityViewController, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension EditPhotoViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isEditingText = true
        
        // プレースホルダーテキストを削除
        if textView.text == "テキストを入力" {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        isEditingText = false
        
        // 空の場合はプレースホルダーを表示
        if textView.text.isEmpty {
            textView.text = "テキストを入力"
            textView.textColor = UIColor.lightGray
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Returnキーで編集終了
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}

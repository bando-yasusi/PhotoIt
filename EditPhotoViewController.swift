import UIKit
import PDFKit

// コンテキストメニューを完全に無効化するカスタムUITextView
class NoMenuTextView: UITextView {
    // 初期化時に必要な設定を行う
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupTextView()
    }
    
    // 必要な初期設定をまとめて行う
    private func setupTextView() {
        // コンテキストメニュー関連の設定
        self.dataDetectorTypes = []
        self.allowsEditingTextAttributes = false
        self.autocorrectionType = .no
        self.autocapitalizationType = .none
        self.spellCheckingType = .no
        self.smartQuotesType = .no
        self.smartDashesType = .no
        self.smartInsertDeleteType = .no
        
        // 長押しジェスチャーを無効化
        for recognizer in self.gestureRecognizers ?? [] {
            if recognizer is UILongPressGestureRecognizer {
                recognizer.isEnabled = false
                self.removeGestureRecognizer(recognizer)
            }
        }
    }
    
    // ファーストレスポンダーになれるようにする（編集のため）
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    // すべてのコンテキストメニューアクションを無効化
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }
    
    // 入力補助アイテムを完全に無効化
    override var inputAssistantItem: UITextInputAssistantItem {
        let assistantItem = super.inputAssistantItem
        assistantItem.leadingBarButtonGroups = []
        assistantItem.trailingBarButtonGroups = []
        return assistantItem
    }
    
    // タッチイベントをオーバーライドして長押しを無効化
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // 長押しジェスチャーを再度無効化（念のため）
        for recognizer in self.gestureRecognizers ?? [] {
            if recognizer is UILongPressGestureRecognizer {
                recognizer.isEnabled = false
            }
        }
    }
    
    // メニューコントローラーを無効化
    override var keyCommands: [UIKeyCommand]? {
        return []
    }
}

class EditPhotoViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    // MARK: - Properties
    var selectedImage: UIImage?
    private var stickyNote: UIView!
    private var stickyImageView: UIImageView!
    private var textView: NoMenuTextView! // カスタムNoMenuTextViewを使用
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
        
        // ズーム機能を徹底的に無効化
        disableAllZoomFunctionality()
        
        // すべてのジェスチャー認識器を確認して無効化
        let allGestureRecognizers = imageView.gestureRecognizers ?? []
        for recognizer in allGestureRecognizers {
            // ダブルタップジェスチャーを無効化
            if let tapRecognizer = recognizer as? UITapGestureRecognizer,
               tapRecognizer.numberOfTapsRequired > 1 {
                tapRecognizer.isEnabled = false
                imageView.removeGestureRecognizer(tapRecognizer)
            }
            
            // ピンチジェスチャーを無効化
            if recognizer is UIPinchGestureRecognizer {
                recognizer.isEnabled = false
                imageView.removeGestureRecognizer(recognizer)
            }
        }
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
        let paddingLeft: CGFloat = 43  // 左側の余白を増やす（45から43に変更）
        let paddingRight: CGFloat = 10
        let paddingVertical: CGFloat = 10
        
        // 付箋のテキストビューを作成（カスタムNoMenuTextViewを使用）
        textView = NoMenuTextView(frame: CGRect(
            x: 43, // 左側に余白を設ける（矢印部分のため）
            y: 0, // 上の余白を完全になくす（2から0に変更）
            width: stickyNote.bounds.width - 53, // 余白を考慮
            height: stickyNote.bounds.height // 下の余白を完全になくす（4から0に変更）
        ))
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 19) // 20から19に変更し、5行入るように調整
        textView.text = "テキストを入力"
        textView.textColor = UIColor.lightGray
        textView.textAlignment = .left // 左詰めに変更
        textView.delegate = self
        textView.returnKeyType = .done
        textView.isScrollEnabled = false
        
        // テキストビューの内部余白を最小限にする
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        
        // 念のため、UIMenuControllerを無効化
        NotificationCenter.default.addObserver(self, selector: #selector(willShowMenu(_:)), name: UIMenuController.willShowMenuNotification, object: nil)
        
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
        if isEditingText {
            // キーボードが隠れたら元の位置に戻す
            UIView.animate(withDuration: 0.3) {
                self.imageView.transform = .identity
            }
        }
    }
    
    // MARK: - Text Input Alert
    private func showTextInputAlert() {
        guard let stickyNote = self.stickyNote else { return }
        
        let alertController = UIAlertController(
            title: "テキストを入力",
            message: nil,
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.text = self.textView.text == "テキストを入力" ? "" : self.textView.text
            textField.placeholder = "テキストを入力してください"
        }
        
        let cancelAction = UIAlertAction(title: "キャンセル", style: .cancel)
        let okAction = UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let textField = alertController.textFields?.first, let text = textField.text {
                if text.isEmpty {
                    self.textView.text = "テキストを入力"
                    self.textView.textColor = UIColor.lightGray
                } else {
                    self.textView.text = text
                    self.textView.textColor = UIColor.black
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        
        isEditingText = true
        present(alertController, animated: true)
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
        
        // 移動量を取得
        let translation = gesture.translation(in: imageView)
        
        // 移動後の予定位置を計算
        let newCenter = CGPoint(
            x: stickyView.center.x + translation.x,
            y: stickyView.center.y + translation.y
        )
        
        // 写真の境界内に収まるように位置を調整
        let constrainedCenter = constrainStickyNotePosition(newCenter)
        stickyView.center = constrainedCenter
        
        // 移動量をリセット
        gesture.setTranslation(.zero, in: imageView)
    }
    
    // 付箋の位置を写真の境界内に制限する
    private func constrainStickyNotePosition(_ proposedCenter: CGPoint) -> CGPoint {
        // 付箋のバウンディングボックスを計算
        let stickyBounds = calculateStickyNoteBoundingBox()
        
        // 付箋の中心から各辺までの距離
        let halfWidth = stickyBounds.width / 2.0
        let halfHeight = stickyBounds.height / 2.0
        
        // 写真の境界
        let minX = halfWidth
        let maxX = imageView.bounds.width - halfWidth
        let minY = halfHeight
        let maxY = imageView.bounds.height - halfHeight
        
        // 境界内に収まるように位置を調整
        let constrainedX = min(max(proposedCenter.x, minX), maxX)
        let constrainedY = min(max(proposedCenter.y, minY), maxY)
        
        return CGPoint(x: constrainedX, y: constrainedY)
    }
    
    // 付箋の実際の表示領域（バウンディングボックス）を計算
    private func calculateStickyNoteBoundingBox() -> CGRect {
        // 回転を考慮したバウンディングボックスを計算
        let originalSize = stickyNote.bounds.size
        
        // 回転角度を取得
        let currentRotation = atan2(stickyNote.transform.b, stickyNote.transform.a)
        
        // 回転を考慮したバウンディングボックスのサイズを計算
        let rotatedWidth = abs(originalSize.width * cos(currentRotation)) + abs(originalSize.height * sin(currentRotation))
        let rotatedHeight = abs(originalSize.width * sin(currentRotation)) + abs(originalSize.height * cos(currentRotation))
        
        // 安全マージンを追加
        let safetyMargin: CGFloat = 5.0
        return CGRect(
            x: 0,
            y: 0,
            width: rotatedWidth + safetyMargin,
            height: rotatedHeight + safetyMargin
        )
    }
    
    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        // タップイベントをキャンセルして他のジェスチャーに伝播しないようにする
        gesture.cancelsTouchesInView = true
        
        // タップしたときにテキストビューにフォーカスを当てる
        if !textView.isFirstResponder {
            textView.becomeFirstResponder()
        }
        
        // UIMenuControllerを確実に無効化
        UIMenuController.shared.hideMenu()
        
        // 他のジェスチャー認識を防止
        if let scrollView = imageView.superview as? UIScrollView {
            // ズームとスクロールを完全に無効化
            scrollView.isScrollEnabled = false
            
            // すべてのズーム関連ジェスチャーを無効化
            if let pinchGesture = scrollView.pinchGestureRecognizer {
                pinchGesture.isEnabled = false
                scrollView.removeGestureRecognizer(pinchGesture)
            }
            
            // すべてのタップジェスチャーを一時的に無効化
            for recognizer in scrollView.gestureRecognizers ?? [] {
                if recognizer is UITapGestureRecognizer {
                    recognizer.isEnabled = false
                }
                
                // ピンチジェスチャーも確実に無効化
                if recognizer is UIPinchGestureRecognizer {
                    recognizer.isEnabled = false
                    scrollView.removeGestureRecognizer(recognizer)
                }
            }
            
            // 編集終了時に再度スクロールを有効にするため、遅延実行
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollView.isScrollEnabled = true
                // ズームは引き続き無効のまま
                self.disableAllZoomFunctionality()
            }
        }
        
        // すべてのタップイベントを消費
        gesture.cancelsTouchesInView = true
        
        // 念のため、ズーム機能を再度無効化
        disableAllZoomFunctionality()
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
        
        // ズームジェスチャーは無視
        if gestureRecognizer is UIPinchGestureRecognizer {
            return false
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // ズームジェスチャーとの同時認識は禁止
        if otherGestureRecognizer is UIPinchGestureRecognizer {
            return false
        }
        
        // 複数のジェスチャーを同時に認識できるようにする
        return true
    }
    
    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // ズーム対象のビューを返さないことでズームを無効化
        return nil
    }
    
    // スクロールビューのすべてのズーム関連メソッドをオーバーライド
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // ズームを防止
        scrollView.pinchGestureRecognizer?.isEnabled = false
        
        // ズームをキャンセル
        scrollView.zoomScale = 1.0
        
        // ズームジェスチャーを完全に削除
        if let pinchGesture = scrollView.pinchGestureRecognizer {
            scrollView.removeGestureRecognizer(pinchGesture)
        }
        
        // 念のため、すべてのズーム機能を再度無効化
        disableAllZoomFunctionality()
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // ズーム後の処理を無効化
        scrollView.zoomScale = 1.0
        disableAllZoomFunctionality()
    }
    
    // スクロールビューがズームを開始する前に呼ばれる
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        // ズームを防止するために必要に応じて設定
        scrollView.zoomScale = 1.0
        return true
    }
    
    // メニューコントローラーの表示を防止
    @objc private func willShowMenu(_ notification: Notification) {
        UIMenuController.shared.hideMenu()
    }
    
    // ズーム機能を徹底的に無効化する関数
    private func disableAllZoomFunctionality() {
        if let scrollView = imageView.superview as? UIScrollView {
            // ズーム関連の設定を無効化
            scrollView.maximumZoomScale = 1.0
            scrollView.minimumZoomScale = 1.0
            scrollView.bouncesZoom = false
            scrollView.delaysContentTouches = false
            scrollView.zoomScale = 1.0
            
            // すべてのズーム関連ジェスチャーを無効化
            if let pinchGesture = scrollView.pinchGestureRecognizer {
                pinchGesture.isEnabled = false
                scrollView.removeGestureRecognizer(pinchGesture)
            }
            
            // スクロールビューのデリゲートを設定
            scrollView.delegate = self
            
            // すべてのジェスチャーを確認して無効化
            for recognizer in scrollView.gestureRecognizers ?? [] {
                // ダブルタップジェスチャーを無効化
                if let tapRecognizer = recognizer as? UITapGestureRecognizer,
                   tapRecognizer.numberOfTapsRequired > 1 {
                    tapRecognizer.isEnabled = false
                    scrollView.removeGestureRecognizer(tapRecognizer)
                }
                
                // ピンチジェスチャーを無効化
                if recognizer is UIPinchGestureRecognizer {
                    recognizer.isEnabled = false
                    scrollView.removeGestureRecognizer(recognizer)
                }
            }
        }
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


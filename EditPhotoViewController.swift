import UIKit
import PDFKit

// コンテキストメニューとタッチ操作を完全に無効化するカスタムUITextView
class NoMenuTextView: UITextView {

    override var canBecomeFirstResponder: Bool {
        return true // キーボードは表示する
    }

    // コピー、ペースト、選択などのメニューを無効化
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        return false
    }

    // 初期化処理
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isEditable = true
        isSelectable = true    // キーボードを表示するため必要
        isScrollEnabled = false // スクロールを無効化
        dataDetectorTypes = [] // URLや電話番号などの検出を無効化
        autocorrectionType = .no
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        inputAssistantItem.leadingBarButtonGroups = [] // 上部バー（ペーストなど）を非表示
        inputAssistantItem.trailingBarButtonGroups = []
        
        // カーソル選択を抑止
        selectedTextRange = nil
        
        // ドラッグアンドドロップを無効化
        textDragInteraction?.isEnabled = false
        
        // ドロップインタラクションを無効化
        if let dropInteraction = textDropInteraction {
            removeInteraction(dropInteraction)
        }
        
        // すべてのジェスチャー認識機を無効化
        if let gestures = gestureRecognizers {
            for gesture in gestures {
                // すべてのジェスチャーを無効化
                gesture.isEnabled = false
                removeGestureRecognizer(gesture)
            }
        }
        
        // メニューを非表示
        UIMenuController.shared.hideMenu()
        
        // メニュー表示通知を監視
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willShowMenu),
                                               name: UIMenuController.willShowMenuNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didShowMenu),
                                               name: UIMenuController.didShowMenuNotification,
                                               object: nil)
        
        // テキスト選択はデリゲートメソッドで処理するので、ここでの通知監視は不要
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // 日本語変換の候補バーを防ぐ（任意）
    override var textInputContextIdentifier: String? {
        return nil
    }

    override var textInputMode: UITextInputMode? {
        return UITextInputMode.activeInputModes.first
    }
    
    // メニューが表示される直前に呼ばれる
    @objc private func willShowMenu(_ notification: Notification) {
        // メニューを強制的に非表示にする
        UIMenuController.shared.hideMenu()
        
        // 非同期でもう一度メニューを非表示にする
        DispatchQueue.main.async {
            UIMenuController.shared.hideMenu()
        }
        
        // さらに別のタイミングでもメニューを非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIMenuController.shared.hideMenu()
        }
    }
    
    // メニューが表示された直後に呼ばれる
    @objc private func didShowMenu(_ notification: Notification) {
        // メニューを強制的に非表示にする
        UIMenuController.shared.hideMenu()
        
        // 非同期でもう一度メニューを非表示にする
        DispatchQueue.main.async {
            UIMenuController.shared.hideMenu()
        }
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        // 念のため再確認
        self.gestureRecognizers?.forEach { recognizer in
            // すべてのジェスチャーを無効化
            recognizer.isEnabled = false
            self.removeGestureRecognizer(recognizer)
        }
        
        // メニューを強制的に非表示
        UIMenuController.shared.hideMenu()
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        self.selectedRange = NSRange(location: self.text.count, length: 0)
        self.selectedTextRange = nil
        // メニューを強制的に非表示
        UIMenuController.shared.hideMenu()
        return result
    }
    
    // 選択範囲の表示を無効化
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return []
    }
    
    // タッチイベントをキャンセル
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIMenuController.shared.hideMenu()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        UIMenuController.shared.hideMenu()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIMenuController.shared.hideMenu()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIMenuController.shared.hideMenu()
    }
    
    // すべてのジェスチャー認識機を無効化
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
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
        stickyNote.addSubview(stickyImageView) // 付箋に画像ビューを追加
        
        // テキストビューを作成
        let textViewFrame = CGRect(
            x: 43, // 矢印の幅を考慮した左余白
            y: 0,  // 上下の余白をなくす
            width: stickyNote.bounds.width - 53, // 左余白を考慮した幅
            height: stickyNote.bounds.height // 上下の余白をなくす
        )
        
        // カスタムテキストビューを作成
        textView = NoMenuTextView(frame: textViewFrame)
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.font = UIFont.systemFont(ofSize: 19)
        textView.textColor = .black
        textView.textAlignment = .left
        textView.text = "テキストを入力"
        textView.textColor = UIColor.lightGray
        
        // テキストビューの内部余白を設定
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        
        stickyNote.addSubview(textView)
        
        // 付箋をイメージビューに追加
        imageView.addSubview(stickyNote)
        
        // ズーム機能を完全に無効化
        disableAllZoomFunctionality()
        
        // メニュー表示通知を監視
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(willShowMenu(_:)),
                                               name: UIMenuController.willShowMenuNotification,
                                               object: nil)
        
        // パンジェスチャーを設定
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        panGesture.cancelsTouchesInView = false // テキスト入力を妨げないようにする
        stickyNote.addGestureRecognizer(panGesture)
        
        // 回転ジェスチャーを設定
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        rotationGesture.delegate = self
        rotationGesture.cancelsTouchesInView = false // テキスト入力を妨げないようにする
        stickyNote.addGestureRecognizer(rotationGesture)
        
        // テキストビューを自動的にファーストレスポンダーにする
        DispatchQueue.main.async {
            self.textView.becomeFirstResponder()
            self.isEditingText = true
            
            // メニューを確実に非表示にする
            UIMenuController.shared.hideMenu()
        }
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
        // タップジェスチャーは新しい仕様では使用しないが、互換性のために残す
        gesture.cancelsTouchesInView = true
        
        // メニューを確実に非表示にする
        UIMenuController.shared.hideMenu()
        
        // ズーム機能を完全に無効化
        disableAllZoomFunctionality()
        
        // テキストビューをファーストレスポンダーにする
        textView.becomeFirstResponder()
        
        // テキスト選択を解除
        if let noMenuTextView = textView as? NoMenuTextView {
            noMenuTextView.selectedRange = NSRange(location: noMenuTextView.selectedRange.location, length: 0)
        }
        
        // 非同期でもう一度メニューを非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIMenuController.shared.hideMenu()
            self.disableAllZoomFunctionality()
        }
        
        // さらに別のタイミングでもメニューを非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIMenuController.shared.hideMenu()
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
        // ズーム機能を完全に無効化するためnilを返す
        return nil
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // ズームを防止
        scrollView.pinchGestureRecognizer?.isEnabled = false
        scrollView.zoomScale = 1.0
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        disableAllZoomFunctionality()
        
        // メニューを強制的に非表示
        UIMenuController.shared.hideMenu()
    }
    

    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // スクロールを無効化
        scrollView.isScrollEnabled = false
        
        // メニューを強制的に非表示
        UIMenuController.shared.hideMenu()
        
        // テキスト選択を解除
        if let textView = self.textView {
            textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
        }
        
        // 非同期でもう一度メニューを非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIMenuController.shared.hideMenu()
        }
    }
    
    // ズーム後の処理を無効化
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        scrollView.zoomScale = 1.0
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 1.0
        disableAllZoomFunctionality()
        
        // メニューを強制的に非表示
        UIMenuController.shared.hideMenu()
    }
    
    // スクロールビューがズームを開始する前に呼ばれる
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        // ズームを防止するために必要に応じて設定
        scrollView.zoomScale = 1.0
        return true
    }
    
    // メニューコントローラーの表示を防止
    @objc private func willShowMenu(_ notification: Notification) {
        // メニューを強制的に非表示にする
        UIMenuController.shared.hideMenu()
        
        // 後で再度表示されるのを防止するため、非同期でもう一度非表示にする
        DispatchQueue.main.async {
            UIMenuController.shared.hideMenu()
        }
        
        // さらに別のタイミングでもメニューを非表示にする
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            UIMenuController.shared.hideMenu()
        }
    }
    
    // ズーム機能を徐底的に無効化する関数
    private func disableAllZoomFunctionality() {
        if let scrollView = imageView.superview as? UIScrollView {
            // ズーム関連のすべての設定を無効化
            scrollView.pinchGestureRecognizer?.isEnabled = false
            scrollView.zoomScale = 1.0
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 1.0
            scrollView.bouncesZoom = false
            scrollView.isScrollEnabled = false
            scrollView.delaysContentTouches = false
            scrollView.canCancelContentTouches = false
            
            // すべてのジェスチャーを確認し、ズーム関連のものを無効化
            if let gestures = scrollView.gestureRecognizers?.compactMap({ $0 }) {
                for recognizer in gestures {
                    if recognizer is UIPinchGestureRecognizer ||
                       recognizer is UILongPressGestureRecognizer ||
                       recognizer is UITapGestureRecognizer {
                        recognizer.isEnabled = false
                        recognizer.cancelsTouchesInView = true
                        scrollView.removeGestureRecognizer(recognizer)
                    }
                }
            }
            
            // メニューを強制的に非表示
            UIMenuController.shared.hideMenu()
            
            // 非同期でもう一度設定を無効化
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollView.pinchGestureRecognizer?.isEnabled = false
                scrollView.zoomScale = 1.0
                scrollView.minimumZoomScale = 1.0
                scrollView.maximumZoomScale = 1.0
                UIMenuController.shared.hideMenu()
            }
        }
        
        // テキストビューの選択を解除
        if let textView = self.textView {
            textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
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
extension EditPhotoViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isEditingText = true
        disableAllZoomFunctionality()
        
        // プレースホルダーテキストを削除
        if textView.text == "テキストを入力" {
            textView.text = ""
            textView.textColor = UIColor.black
        }
        
        // 選択を解除
        if let textView = textView as? NoMenuTextView {
            textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
            textView.selectedTextRange = nil
        }
        UIMenuController.shared.hideMenu()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        isEditingText = false
        UIMenuController.shared.hideMenu()
        
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
    
    // テキスト選択を無効化
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        // 選択を解除してメニュー表示を防止
        textView.selectedTextRange = nil
        
        // メニューを強制的に非表示
        UIMenuController.shared.hideMenu()
        
        // ズーム機能を無効化
        disableAllZoomFunctionality()
        
        return true
    }
    
    // テキスト選択時の処理
    func textViewDidChangeSelection(_ textView: UITextView) {
        // すべての選択を即座に解除
        if let noMenuTextView = textView as? NoMenuTextView {
            // 選択があれば解除
            if noMenuTextView.selectedRange.length > 0 {
                // カーソル位置を保持しつつ選択を解除
                let cursorPosition = noMenuTextView.selectedRange.location + noMenuTextView.selectedRange.length
                noMenuTextView.selectedRange = NSRange(location: cursorPosition, length: 0)
            }
            
            // メニューを強制的に非表示にする
            UIMenuController.shared.hideMenu()
            
            // 非同期でもう一度メニューを非表示にする
            DispatchQueue.main.async {
                UIMenuController.shared.hideMenu()
            }
            
            // さらに別のタイミングでもメニューを非表示にする
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                UIMenuController.shared.hideMenu()
                if noMenuTextView.selectedRange.length > 0 {
                    let cursorPosition = noMenuTextView.selectedRange.location + noMenuTextView.selectedRange.length
                    noMenuTextView.selectedRange = NSRange(location: cursorPosition, length: 0)
                }
            }
            
            // さらに別のタイミングでもメニューを非表示にする
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIMenuController.shared.hideMenu()
            }
            
            // ズーム機能も無効化
            self.disableAllZoomFunctionality()
        }
    }
}


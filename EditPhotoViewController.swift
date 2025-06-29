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
        // 基本設定
        isEditable = true
        isSelectable = true    // キーボードを表示するため必要
        isScrollEnabled = false // スクロールを無効化
        dataDetectorTypes = [] // URLや電話番号などの検出を無効化
        
        // 自動修正と入力補助を無効化
        autocorrectionType = .no
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        inputAssistantItem.leadingBarButtonGroups = [] // 上部バー（ペーストなど）を非表示
        inputAssistantItem.trailingBarButtonGroups = []
        
        // ドラッグアンドドロップを無効化
        textDragInteraction?.isEnabled = false
        if let dropInteraction = textDropInteraction {
            removeInteraction(dropInteraction)
        }
        
        // すべてのジェスチャー認識機を無効化
        if let gestures = gestureRecognizers {
            for gesture in gestures {
                gesture.isEnabled = false
                removeGestureRecognizer(gesture)
            }
        }
        
        // メニューを非表示
        UIMenuController.shared.hideMenu()
        
        // メニュー表示通知を監視
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(hideMenuWhenShown),
                                               name: UIMenuController.willShowMenuNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(hideMenuWhenShown),
                                               name: UIMenuController.didShowMenuNotification,
                                               object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // 日本語変換の候補バーを防ぐ
    override var textInputContextIdentifier: String? {
        return nil
    }

    override var textInputMode: UITextInputMode? {
        return UITextInputMode.activeInputModes.first
    }
    
    // メニューが表示されようとした時に呼ばれる
    @objc private func hideMenuWhenShown(_ notification: Notification) {
        // メニューを強制的に非表示にする
        UIMenuController.shared.hideMenu()
        
        // 非同期でもう一度メニューを非表示にする
        DispatchQueue.main.async {
            UIMenuController.shared.hideMenu()
        }
    }
    
    // 選択範囲の表示を無効化
    override func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return []
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

class EditPhotoViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UITextViewDelegate {
    
    // MARK: - IBOutlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    
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
        
        // 画面表示後、すぐにテキストビューにフォーカスを当てる
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // テキストの色を黒に設定
            self.textView.textColor = UIColor.black
            
            // テキストビューを編集可能にする
            if self.textView.becomeFirstResponder() {
                self.isEditingText = true
            } else {
                print("テキストビューがファーストレスポンダーになれませんでした")
                // 失敗時でもテキスト編集モードにする
                self.isEditingText = true
            }
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
        textView.text = "" // 初期状態では空にする
        
        // テキストビューの内部余白を設定
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        
        stickyNote.addSubview(textView)
        
        // 付箋をイメージビューに追加
        imageView.addSubview(stickyNote)
        
        // ズーム機能を完全に無効化
        disableAllZoomFunctionality()
        
        // メニュー表示通知の監視はNoMenuTextView内で行うのでここでは不要
        
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
        let _ = textView.becomeFirstResponder() // 戻り値を使用しないことを明示
        
        // テキスト選択を解除
        textView.selectedRange = NSRange(location: textView.selectedRange.location, length: 0)
        
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
        // ズーム機能を無効化するためnilを返す
        return nil
    }
    
    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // ズームを防止
        disableAllZoomFunctionality()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // スクロールを無効化
        scrollView.isScrollEnabled = false
    }
    
    // ズーム後の処理を無効化
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        disableAllZoomFunctionality()
    }
    
    // ズーム機能を無効化する関数
    private func disableAllZoomFunctionality() {
        if let scrollView = imageView.superview as? UIScrollView {
            // ズーム関連の設定を無効化
            scrollView.pinchGestureRecognizer?.isEnabled = false
            scrollView.zoomScale = 1.0
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 1.0
            scrollView.bouncesZoom = false
            scrollView.isScrollEnabled = false
            
            // ズーム関連のジェスチャーを無効化
            if let gestures = scrollView.gestureRecognizers?.compactMap({ $0 }) {
                for recognizer in gestures {
                    if recognizer is UIPinchGestureRecognizer ||
                       recognizer is UILongPressGestureRecognizer ||
                       recognizer is UITapGestureRecognizer {
                        recognizer.isEnabled = false
                        scrollView.removeGestureRecognizer(recognizer)
                    }
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
            showErrorMessage("画像のキャプチャに失敗しました")
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
        
        // PhotoItフォルダに保存
        saveToPhotoItFolder(pdfData: pdfData as Data)
    }
    
    // PhotoItフォルダへの保存処理
    private func saveToPhotoItFolder(pdfData: Data) {
        // フォルダ作成（存在しない場合）
        guard let photoItFolder = createPhotoItFolderIfNeeded() else {
            showErrorMessage("保存先フォルダの作成に失敗しました")
            return
        }
        
        // ユニークなファイル名生成
        let fileName = generateUniqueFileName(in: photoItFolder)
        let fileURL = photoItFolder.appendingPathComponent(fileName)
        
        // ファイル保存
        do {
            try pdfData.write(to: fileURL)
            showSuccessMessage("保存完了：ファイルアプリのPhotoItフォルダに保存しました")
            
            // オプション：ファイルを開くボタンを表示
            showOpenFileOption(fileURL: fileURL)
        } catch {
            showErrorMessage("保存に失敗しました：\(error.localizedDescription)")
        }
    }
    
    // PhotoItフォルダの作成（存在しない場合）
    private func createPhotoItFolderIfNeeded() -> URL? {
        let fileManager = FileManager.default
        
        // ドキュメントディレクトリを取得
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ドキュメントディレクトリの取得に失敗しました")
            return nil
        }
        
        print("ドキュメントディレクトリ: \(documentsDirectory.path)")
        
        // PhotoItフォルダのパスを作成
        let photoItFolder = documentsDirectory.appendingPathComponent("PhotoIt")
        
        // フォルダが存在しない場合は作成
        if !fileManager.fileExists(atPath: photoItFolder.path) {
            do {
                // 中間ディレクトリも含めて作成
                try fileManager.createDirectory(at: photoItFolder, withIntermediateDirectories: true, attributes: nil)
                print("PhotoItフォルダを作成しました: \(photoItFolder.path)")
                
                // フォルダにダミーファイルを作成して、ファイルアプリで表示されるようにする
                let dummyFilePath = photoItFolder.appendingPathComponent(".dummy")
                if !fileManager.fileExists(atPath: dummyFilePath.path) {
                    try "PhotoIt Folder".write(to: dummyFilePath, atomically: true, encoding: .utf8)
                }
                
                // ファイルシステムの更新を待機
                Thread.sleep(forTimeInterval: 0.1)
            } catch {
                print("フォルダ作成エラー: \(error)")
                return nil
            }
        } else {
            print("PhotoItフォルダは既に存在します: \(photoItFolder.path)")
        }
        
        // 作成したフォルダが実際に存在することを確認
        guard fileManager.fileExists(atPath: photoItFolder.path) else {
            print("フォルダが作成されたはずなのに存在しません: \(photoItFolder.path)")
            return nil
        }
        
        return photoItFolder
    }
    
    // ユニークなファイル名の生成
    private func generateUniqueFileName(in folder: URL) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        // 連番の確認と生成
        var counter = 1
        var fileName = "PhotoIt_\(dateString)_\(String(format: "%03d", counter)).pdf"
        
        // 同名ファイルがある場合は連番を増やす
        while FileManager.default.fileExists(atPath: folder.appendingPathComponent(fileName).path) {
            counter += 1
            fileName = "PhotoIt_\(dateString)_\(String(format: "%03d", counter)).pdf"
        }
        
        return fileName
    }
    
    // 成功メッセージを表示
    private func showSuccessMessage(_ message: String) {
        let alert = UIAlertController(
            title: "保存完了",
            message: message + "\n\nファイルアプリを開き、「このiPhone内」>「PhotoIt」フォルダで確認できます。",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // エラーメッセージの表示
    private func showErrorMessage(_ message: String) {
        let alert = UIAlertController(title: "エラー", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // ファイルを開くオプションを表示
    private func showOpenFileOption(fileURL: URL) {
        // ファイル名を取得
        let fileName = fileURL.lastPathComponent
        
        let message = """
        PDFを保存しました：\(fileName)
        
        ファイルは「ファイル」アプリで確認できます：
        1. 「ファイル」アプリを開く
        2. 「この iPhone 内」をタップ
        3. 「PhotoIt」フォルダを開く
        """
        
        let alert = UIAlertController(
            title: "ファイルを開く",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "開く", style: .default) { _ in
            // ファイルを開く
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            self.present(activityVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: "ファイルアプリで見る", style: .default) { _ in
            // ファイルアプリを開く
            if let fileApp = URL(string: "shareddocuments://") {
                UIApplication.shared.open(fileApp)
            }
        })
        
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        
        // 最初のアラートが閉じた後に表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.present(alert, animated: true)
        }
    }

}

// MARK: - UITextViewDelegate
extension EditPhotoViewController {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isEditingText = true
        
        // 入力テキストの色を黒にする
        textView.textColor = UIColor.black
        
        // ズーム機能を無効化
        disableAllZoomFunctionality()
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        // 編集状態を維持
        isEditingText = true
        
        // テキストの色を黒に設定
        textView.textColor = UIColor.black
        
        // キーボードを表示し続ける
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // 文字数制限（80文字まで）
        let currentText = textView.text ?? ""
        let newLength = currentText.count + text.count - range.length
        
        // 80文字を超える場合は入力を無視
        if newLength > 80 {
            return false
        }
        
        // Returnキーが押された場合
        if text == "\n" {
            // 現在の行数をカウント
            let currentLineCount = self.countLines(in: textView)
            
            // 既に5行ある場合は改行を無視
            if currentLineCount >= 5 {
                return false
            }
        }
        
        return true
    }
    
    // テキスト変更時の処理
    func textViewDidChange(_ textView: UITextView) {
        // テキストの色を黒に設定
        textView.textColor = UIColor.black

        // 行数と文字数の制限を適用
        let maxLines = 5
        let maxCharacters = 80

        // 現在の行数を取得
        let lineCount = self.countLines(in: textView)

        // 文字数制限を適用
        if textView.text.count > maxCharacters {
            // 最大文字数に制限
            textView.text = String(textView.text.prefix(maxCharacters))

            // カーソルを最後に移動
            let newPosition = textView.position(from: textView.beginningOfDocument, offset: maxCharacters)
            if let newPosition = newPosition {
                textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
            }
        }

        // 改行数の制限を適用
        if lineCount > maxLines {
            // 最後の改行を削除
            if let lastNewlineRange = textView.text.range(of: "\n", options: .backwards) {
                textView.text.removeSubrange(lastNewlineRange.lowerBound..<textView.text.endIndex)

                // カーソルを最後に移動
                let newPosition = textView.position(from: textView.beginningOfDocument, offset: textView.text.count)
                if let newPosition = newPosition {
                    textView.selectedTextRange = textView.textRange(from: newPosition, to: newPosition)
                }
            }
        }
    }

}

// MARK: - テキスト行数カウント機能
extension EditPhotoViewController {
    // テキストビューの行数をカウントするメソッド
    private func getLinesFromText(_ text: String) -> [String] {
        return text.components(separatedBy: "\n")
    }

    // テキストビューの行数をカウント
    func countLines(in textView: UITextView) -> Int {
        let text = textView.text ?? ""
        let font = textView.font ?? UIFont.systemFont(ofSize: 19)
        
        // 空の場合は0行
        if text.isEmpty {
            return 0
        }
        
        let textStorage = NSTextStorage(string: text, attributes: [.font: font])
        let textContainer = NSTextContainer(size: textView.bounds.size)
        textContainer.lineFragmentPadding = 0 // 付箱の設定に合わせる
        
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        // 行数をカウント
        var lineCount = 0
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, _, _, _, _ in
            lineCount += 1
        }
        
        return lineCount
    }
}

// MARK: - UITextViewDelegate
extension EditPhotoViewController {
    
    // テキスト編集開始時の処理
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        // ズーム機能を無効化
        disableAllZoomFunctionality()
        return true
    }
    
    // テキスト選択時の処理
    func textViewDidChangeSelection(_ textView: UITextView) {
        // すべての選択を即座に解除
        if let noMenuTextView = textView as? NoMenuTextView, noMenuTextView.selectedRange.length > 0 {
            // カーソル位置を保持しつつ選択を解除
            let cursorPosition = noMenuTextView.selectedRange.location + noMenuTextView.selectedRange.length
            noMenuTextView.selectedRange = NSRange(location: cursorPosition, length: 0)
        }
        
        // メニューを非表示にする
        UIMenuController.shared.hideMenu()
    }
}


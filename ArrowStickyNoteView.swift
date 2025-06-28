import UIKit

protocol ArrowStickyNoteViewDelegate: AnyObject {
    func stickyNoteDidBeginEditing(_ stickyNote: ArrowStickyNoteView)
    func stickyNoteDidEndEditing(_ stickyNote: ArrowStickyNoteView)
}

class ArrowStickyNoteView: UIView, UIGestureRecognizerDelegate {
    
    // MARK: - Properties
    weak var delegate: ArrowStickyNoteViewDelegate?
    
    let placeholderText = "テキストを入力"
    
    var text: String {
        get {
            return textView.text == placeholderText ? "" : textView.text
        }
        set {
            if newValue.isEmpty {
                textView.text = placeholderText
                textView.textColor = UIColor.lightGray
            } else {
                textView.text = newValue
                textView.textColor = UIColor.black
            }
        }
    }
    
    let textView: UITextView = {
        let textView = UITextView()
        textView.textAlignment = .center
        textView.textColor = .lightGray // 初期状態はプレースホルダーなのでライトグレー
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.returnKeyType = .done
        return textView
    }()
    
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "arrow_left_yellow") // 付箋の画像名
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - UITextViewDelegate
    func textViewDidBeginEditing(_ textView: UITextView) {
        delegate?.stickyNoteDidBeginEditing(self)
        
        // プレースホルダーテキストを削除
        if textView.text == placeholderText {
            textView.text = ""
            textView.textColor = UIColor.black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        delegate?.stickyNoteDidEndEditing(self)
        
        // 空の場合はプレースホルダーを表示
        if textView.text.isEmpty {
            textView.text = placeholderText
            textView.textColor = UIColor.lightGray
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // テキストビューがファーストレスポンダーの場合はテキスト編集を優先
        if textView.isFirstResponder && textView.bounds.contains(convert(point, to: textView)) {
            return textView
        }
        
        // ポイントがビュー内にある場合は、このビュー自体を返す（ジェスチャー認識のため）
        if self.bounds.contains(point) {
            return self
        }
        
        return super.hitTest(point, with: event)
    }
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // テキスト編集中はジェスチャーを無視しない
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 複数のジェスチャーを同時に認識できるようにする
        return true
    }
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        // 画像ビューをフレームベースでセットアップ
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.isUserInteractionEnabled = false // 画像ビューはタッチを通過
        addSubview(imageView)
        
        // テキストビューをフレームベースでセットアップ
        let padding: CGFloat = 10
        textView.frame = bounds.insetBy(dx: padding, dy: padding)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.delegate = self
        textView.text = placeholderText
        addSubview(textView)
    }
    
    // テキストの向きを調整するメソッド
    func adjustTextRotation(for rotation: CGFloat) {
        // 付箋が上下逆さまになったとき（90度〜270度の間）にテキストを180度回転させる
        let normalizedRotation = ((rotation * 180 / .pi) + 360).truncatingRemainder(dividingBy: 360)
        
        if (normalizedRotation > 90 && normalizedRotation < 270) {
            // 上下逆さまのとき、テキストを180度回転
            textView.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            // 通常の向き
            textView.transform = .identity
        }
    }
}

// MARK: - UITextViewDelegate
extension ArrowStickyNoteView: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Returnキーで編集終了
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}

import UIKit

protocol ArrowStickyNoteViewDelegate: AnyObject {
    func stickyNoteDidBeginEditing(_ stickyNote: ArrowStickyNoteView)
    func stickyNoteDidEndEditing(_ stickyNote: ArrowStickyNoteView)
}

class ArrowStickyNoteView: UIView {
    
    // MARK: - Properties
    weak var delegate: ArrowStickyNoteViewDelegate?
    
    var text: String {
        get { return textView.text }
        set { textView.text = newValue }
    }
    
    let textView: UITextView = {
        let textView = UITextView()
        textView.textAlignment = .center
        textView.textColor = .black
        textView.font = UIFont.systemFont(ofSize: 14)
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.returnKeyType = .done
        return textView
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "arrow_left_yellow")
        imageView.contentMode = .scaleToFill
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result == textView && textView.isFirstResponder {
            return textView
        }
        return result == textView ? self : result
    }
    
    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        addSubview(imageView)
        addSubview(textView)
        
        textView.delegate = self
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            textView.centerXAnchor.constraint(equalTo: centerXAnchor),
            textView.centerYAnchor.constraint(equalTo: centerYAnchor),
            textView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.8),
            textView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.8)
        ])
    }
    
    // MARK: - Public Methods
    func adjustTextRotation(for rotation: CGFloat) {
        // テキストは付箋と一緒に回転するため、基本的には何もしない
        // 90度を超えると文字の向きを反転させる
        let normalizedRotation = rotation.truncatingRemainder(dividingBy: 2 * .pi)
        let absoluteRotation = abs(normalizedRotation)
        
        // 90度〜270度の間は文字を180度回転させる
        if (absoluteRotation > .pi/2 && absoluteRotation < 3 * .pi/2) {
            textView.transform = CGAffineTransform(rotationAngle: .pi)
        } else {
            textView.transform = CGAffineTransform.identity
        }
    }
}

// MARK: - UITextViewDelegate
extension ArrowStickyNoteView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        delegate?.stickyNoteDidBeginEditing(self)
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        delegate?.stickyNoteDidEndEditing(self)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}

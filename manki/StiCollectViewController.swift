//
//  StiCollectViewController.swift
//  manki
//
//  Created by 井上　希稟 on 2026/01/29.
//

import UIKit

final class StiCollectViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    private var stickers: [SavedSticker] = []
    private var stickerWordMap: [String: [SavedWord]] = [:]
    private var collectionView: UICollectionView!
    private let emptyLabel = UILabel()
    var selectionHandler: ((SavedSticker) -> Void)?
    private let headerReuseID = "StickerAlbumHeaderView"

    override func viewDidLoad() {
        super.viewDidLoad()

        title = selectionHandler == nil ? "ステッカーコレクション" : "ステッカーを選ぶ"
        view.backgroundColor = .systemBackground
        ThemeManager.applyNavigationAppearance(to: navigationController)
        configureCollectionView()
        configureEmptyLabel()
        configureSelectionBarItem()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ThemeManager.applyNavigationAppearance(to: navigationController)
        reloadStickers()
    }

    private func configureCollectionView() {
        let layout = StickerAlbumLayout()
        layout.minimumLineSpacing = AppSpacing.s(16)
        layout.minimumInteritemSpacing = AppSpacing.s(12)
        layout.sectionInset = UIEdgeInsets(top: AppSpacing.s(12),
                                           left: AppSpacing.s(8),
                                           bottom: AppSpacing.s(24),
                                           right: AppSpacing.s(8))
        layout.headerReferenceSize = CGSize(width: view.bounds.width, height: 140)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StickerCell.self, forCellWithReuseIdentifier: StickerCell.reuseID)
        collectionView.register(StickerAlbumHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: headerReuseID)
        collectionView.backgroundView = PaperBackgroundView()

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppSpacing.s(16)),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppSpacing.s(16)),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppSpacing.s(16)),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureEmptyLabel() {
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "まだステッカーがありません"
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = AppFont.jp(size: 16, weight: .bold)
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true

        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func reloadStickers() {
        stickers = StickerStore.loadStickers()
        let words = loadSavedWords()
        stickerWordMap = Dictionary(grouping: words.compactMap { word in
            guard word.illustrationImageFileName != nil else { return nil }
            return word
        }, by: { $0.illustrationImageFileName ?? "" })
        collectionView.reloadData()
        emptyLabel.isHidden = !stickers.isEmpty
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        stickers.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StickerCell.reuseID,
                                                            for: indexPath) as? StickerCell else {
            return UICollectionViewCell()
        }
        let sticker = stickers[indexPath.item]
        let wordText = wordLabelText(for: sticker.imageFileName)
        let rarity = StickerRarity.fromSeed(sticker.imageFileName)
        cell.configure(with: StickerStore.loadStickerImage(fileName: sticker.imageFileName),
                       wordText: wordText,
                       rarity: rarity)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let sticker = stickers[indexPath.item]
        if let selectionHandler {
            selectionHandler(sticker)
            if let nav = navigationController, nav.viewControllers.first != self {
                nav.popViewController(animated: true)
            } else {
                dismiss(animated: true)
            }
            return
        }

        presentUnifiedModal(
            title: "ステッカー",
            message: "このステッカーを削除しますか？",
            actions: [
                UnifiedModalAction(title: "削除", style: .destructive) { [weak self] in
                    self?.deleteSticker(at: indexPath)
                },
                UnifiedModalAction(title: "キャンセル", style: .cancel)
            ]
        )
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let columns: CGFloat = 3
        let layout = collectionViewLayout as? UICollectionViewFlowLayout
        let insets = layout?.sectionInset ?? .zero
        let spacing = layout?.minimumInteritemSpacing ?? 0
        let totalSpacing: CGFloat = (columns - 1) * spacing + insets.left + insets.right
        let width = floor((collectionView.bounds.width - totalSpacing) / columns)
        let height = width + AppSpacing.s(38)
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                           withReuseIdentifier: headerReuseID,
                                                                           for: indexPath) as? StickerAlbumHeaderView else {
            return UICollectionReusableView()
        }
        header.configure(stickerCount: stickers.count)
        return header
    }

    private func configureSelectionBarItem() {
        guard selectionHandler != nil else { return }
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "閉じる",
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(closeTapped))
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func deleteSticker(at indexPath: IndexPath) {
        guard indexPath.item < stickers.count else { return }
        let sticker = stickers[indexPath.item]
        StickerStore.deleteStickerImage(fileName: sticker.imageFileName)
        stickers.remove(at: indexPath.item)
        StickerStore.saveStickers(stickers)
        collectionView.deleteItems(at: [indexPath])
        emptyLabel.isHidden = !stickers.isEmpty
    }

    private func wordLabelText(for fileName: String) -> NSAttributedString? {
        guard let words = stickerWordMap[fileName], let first = words.first else { return nil }
        let englishAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.en(size: 14, weight: .regular),
            .foregroundColor: UIColor.label
        ]
        let japaneseAttributes: [NSAttributedString.Key: Any] = [
            .font: AppFont.jp(size: 12, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel
        ]
        let result = NSMutableAttributedString(string: first.english, attributes: englishAttributes)
        var japaneseLine = first.japanese
        if words.count > 1 {
            japaneseLine += " ほか\(words.count - 1)"
        }
        result.append(NSAttributedString(string: "\n", attributes: japaneseAttributes))
        result.append(NSAttributedString(string: japaneseLine, attributes: japaneseAttributes))
        return result
    }

    private func loadSavedWords() -> [SavedWord] {
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask).first!
        let fileURL = documents.appendingPathComponent("saved_words.json")
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([SavedWord].self, from: data) {
            return decoded
        }
        let legacy = UserDefaults.standard.array(forKey: "WORD") as? [[String: String]] ?? []
        return legacy.map {
            SavedWord(english: $0["english"] ?? "",
                      japanese: $0["japanese"] ?? "",
                      illustrationScenario: nil,
                      illustrationImageFileName: nil)
        }
    }
}

private enum StickerRarity: CaseIterable {
    case common
    case rare
    case epic

    static func fromSeed(_ seed: String) -> StickerRarity {
        let hash = abs(seed.hashValue)
        switch hash % 10 {
        case 0, 1:
            return .epic
        case 2, 3, 4:
            return .rare
        default:
            return .common
        }
    }
}

private final class StickerCell: UICollectionViewCell {
    static let reuseID = "StickerCell"

    private let imageView = UIImageView()
    private let wordLabel = UILabel()
    private let tapeView = UIView()
    private let shimmerLayer = CAGradientLayer()
    private var sparkleLayer: CAEmitterLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        contentView.backgroundColor = UIColor.white
        contentView.layer.cornerRadius = 14
        contentView.clipsToBounds = true
        contentView.layer.borderWidth = 2
        contentView.layer.borderColor = UIColor(white: 0.95, alpha: 1).cgColor

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)

        tapeView.translatesAutoresizingMaskIntoConstraints = false
        tapeView.backgroundColor = UIColor(red: 0.98, green: 0.93, blue: 0.74, alpha: 0.9)
        tapeView.layer.cornerRadius = 6
        tapeView.transform = CGAffineTransform(rotationAngle: -0.06)
        contentView.addSubview(tapeView)

        wordLabel.translatesAutoresizingMaskIntoConstraints = false
        wordLabel.numberOfLines = 2
        wordLabel.textAlignment = .center
        contentView.addSubview(wordLabel)

        NSLayoutConstraint.activate([
            tapeView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(6)),
            tapeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(10)),
            tapeView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(24)),
            tapeView.heightAnchor.constraint(equalToConstant: 16),

            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(8)),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(8)),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(8)),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),

            wordLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: AppSpacing.s(6)),
            wordLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(6)),
            wordLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(6)),
            wordLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(6))
        ])

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        shimmerLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.55).cgColor,
            UIColor.clear.cgColor
        ]
        shimmerLayer.startPoint = CGPoint(x: 0, y: 0)
        shimmerLayer.endPoint = CGPoint(x: 1, y: 1)
        shimmerLayer.isHidden = true
        contentView.layer.addSublayer(shimmerLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 14).cgPath
        shimmerLayer.frame = contentView.bounds.insetBy(dx: -20, dy: -20)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        shimmerLayer.isHidden = true
        shimmerLayer.removeAllAnimations()
        sparkleLayer?.removeFromSuperlayer()
        sparkleLayer = nil
        contentView.layer.borderColor = UIColor(white: 0.95, alpha: 1).cgColor
    }

    func configure(with image: UIImage?, wordText: NSAttributedString?, rarity: StickerRarity) {
        imageView.image = image
        wordLabel.attributedText = wordText
        wordLabel.isHidden = (wordText == nil)
        applyRarity(rarity)
    }

    private func applyRarity(_ rarity: StickerRarity) {
        switch rarity {
        case .common:
            shimmerLayer.isHidden = true
            contentView.layer.borderColor = UIColor(white: 0.95, alpha: 1).cgColor
        case .rare:
            shimmerLayer.isHidden = false
            contentView.layer.borderColor = UIColor(red: 0.78, green: 0.86, blue: 1.0, alpha: 1).cgColor
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = -bounds.width
            animation.toValue = bounds.width
            animation.duration = 2.4
            animation.repeatCount = .infinity
            shimmerLayer.add(animation, forKey: "shimmer")
        case .epic:
            shimmerLayer.isHidden = false
            contentView.layer.borderColor = UIColor(red: 1.0, green: 0.82, blue: 0.4, alpha: 1).cgColor
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = -bounds.width
            animation.toValue = bounds.width
            animation.duration = 1.8
            animation.repeatCount = .infinity
            shimmerLayer.add(animation, forKey: "shimmer")
            if sparkleLayer == nil {
                let emitter = CAEmitterLayer()
                emitter.emitterPosition = CGPoint(x: bounds.midX, y: 0)
                emitter.emitterSize = CGSize(width: bounds.width, height: 1)
                emitter.emitterShape = .line
                let cell = CAEmitterCell()
                cell.birthRate = 6
                cell.lifetime = 1.6
                cell.velocity = 20
                cell.velocityRange = 30
                cell.emissionRange = .pi
                cell.scale = 0.02
                cell.scaleRange = 0.03
                cell.alphaSpeed = -0.4
                cell.contents = UIImage(systemName: "sparkle")?.withTintColor(.white, renderingMode: .alwaysOriginal).cgImage
                emitter.emitterCells = [cell]
                contentView.layer.addSublayer(emitter)
                sparkleLayer = emitter
            }
        }
    }
}

private final class StickerAlbumLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let attributes = super.layoutAttributesForElements(in: rect) else { return nil }
        return attributes.map { attr in
            guard attr.representedElementCategory == .cell else { return attr }
            let copy = attr.copy() as! UICollectionViewLayoutAttributes
            let seed = copy.indexPath.section * 10_000 + copy.indexPath.item
            let jitter = StickerAlbumLayout.jitter(for: seed)
            copy.center = CGPoint(x: copy.center.x + jitter.dx, y: copy.center.y + jitter.dy)
            copy.transform = CGAffineTransform(rotationAngle: jitter.rotation)
            copy.zIndex = 1 + (seed % 5)
            return copy
        }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }

    private static func jitter(for seed: Int) -> (dx: CGFloat, dy: CGFloat, rotation: CGFloat) {
        let s = CGFloat(seed)
        let dx = (sin(s * 0.13) * 4.0)
        let dy = (cos(s * 0.21) * 5.0)
        let rotation = sin(s * 0.07) * 0.06
        return (dx, dy, rotation)
    }
}

private final class PaperBackgroundView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1)
        isOpaque = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1)
        isOpaque = true
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 1).cgColor)
        ctx.fill(rect)

        let lineColor = UIColor(red: 0.85, green: 0.89, blue: 0.93, alpha: 0.35).cgColor
        ctx.setStrokeColor(lineColor)
        ctx.setLineWidth(1)

        let lineSpacing: CGFloat = 22
        var y: CGFloat = 24
        while y < rect.height {
            ctx.move(to: CGPoint(x: 18, y: y))
            ctx.addLine(to: CGPoint(x: rect.width - 12, y: y))
            y += lineSpacing
        }
        ctx.strokePath()

        let holeColor = UIColor(white: 0.85, alpha: 0.8).cgColor
        ctx.setFillColor(holeColor)
        let holeX: CGFloat = 12
        let holeRadius: CGFloat = 6
        let holeSpacing: CGFloat = 64
        var holeY: CGFloat = 40
        while holeY < rect.height {
            let holeRect = CGRect(x: holeX - holeRadius,
                                  y: holeY - holeRadius,
                                  width: holeRadius * 2,
                                  height: holeRadius * 2)
            ctx.fillEllipse(in: holeRect)
            holeY += holeSpacing
        }

        ctx.setFillColor(UIColor(white: 0, alpha: 0.05).cgColor)
        for i in 0..<180 {
            let rx = CGFloat((i * 37) % Int(rect.width))
            let ry = CGFloat((i * 53) % Int(rect.height))
            ctx.fill(CGRect(x: rx, y: ry, width: 1, height: 1))
        }
    }
}

private final class StickerAlbumHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let tagLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = UIColor(red: 0.96, green: 0.87, blue: 1.0, alpha: 0.6)
        layer.cornerRadius = 16
        layer.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = AppFont.en(size: 22, weight: .bold)
        titleLabel.text = "Sticker Album"
        titleLabel.textColor = UIColor(red: 0.2, green: 0.1, blue: 0.35, alpha: 1)
        addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = AppFont.jp(size: 16, weight: .bold)
        subtitleLabel.text = "ステッカー帳"
        subtitleLabel.textColor = UIColor(red: 0.3, green: 0.18, blue: 0.45, alpha: 1)
        addSubview(subtitleLabel)

        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        tagLabel.font = AppFont.en(size: 12, weight: .regular)
        tagLabel.textColor = UIColor(red: 0.35, green: 0.2, blue: 0.5, alpha: 1)
        addSubview(tagLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: AppSpacing.s(16)),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: AppSpacing.s(18)),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: AppSpacing.s(6)),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            tagLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: AppSpacing.s(8)),
            tagLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor)
        ])
    }

    func configure(stickerCount: Int) {
        tagLabel.text = "since 2026  •  collected \(stickerCount)"
    }
}

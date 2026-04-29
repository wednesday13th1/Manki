import UIKit

final class ImportRowCell: UITableViewCell {
    static let reuseID = "ImportRowCell"

    private let termLabel = UILabel()
    private let meaningLabel = UILabel()
    private let divider = UIView()

    var onTermTapped: (() -> Void)?
    var onMeaningTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        selectionStyle = .none
        setupUI()
    }

    private func setupUI() {
        // 左右2カラムの簡易レイアウト
        termLabel.translatesAutoresizingMaskIntoConstraints = false
        meaningLabel.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false

        termLabel.numberOfLines = 0
        meaningLabel.numberOfLines = 0

        termLabel.font = AppFont.jp(size: 16, weight: .bold)
        meaningLabel.font = AppFont.jp(size: 16)

        divider.backgroundColor = UIColor.systemGray4

        contentView.addSubview(termLabel)
        contentView.addSubview(meaningLabel)
        contentView.addSubview(divider)

        let termTap = UITapGestureRecognizer(target: self, action: #selector(termTapped))
        termLabel.isUserInteractionEnabled = true
        termLabel.addGestureRecognizer(termTap)

        let meaningTap = UITapGestureRecognizer(target: self, action: #selector(meaningTapped))
        meaningLabel.isUserInteractionEnabled = true
        meaningLabel.addGestureRecognizer(meaningTap)

        NSLayoutConstraint.activate([
            termLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppSpacing.s(16)),
            termLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(12)),
            termLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(12)),
            termLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.45),

            divider.leadingAnchor.constraint(equalTo: termLabel.trailingAnchor, constant: AppSpacing.s(8)),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(10)),
            divider.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(10)),

            meaningLabel.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: AppSpacing.s(8)),
            meaningLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppSpacing.s(16)),
            meaningLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppSpacing.s(12)),
            meaningLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppSpacing.s(12))
        ])
    }

    func configure(term: String, meaning: String, isUnclassified: Bool) {
        // 空欄はプレースホルダ表示
        termLabel.text = term.isEmpty ? "(タップで入力)" : term
        meaningLabel.text = meaning.isEmpty ? "(タップで入力)" : meaning
        termLabel.textColor = term.isEmpty ? .secondaryLabel : .label
        meaningLabel.textColor = meaning.isEmpty ? .secondaryLabel : .label
        contentView.backgroundColor = isUnclassified ? UIColor.systemYellow.withAlphaComponent(0.1) : .clear
    }

    @objc private func termTapped() {
        onTermTapped?()
    }

    @objc private func meaningTapped() {
        onMeaningTapped?()
    }
}

import UIKit

struct PDFExporter {

    static let shared = PDFExporter()
    private init() {}

    // MARK: — Layout constants

    private let pageSize = CGSize(width: 595, height: 842)
    private let margin: CGFloat = 56
    private let headerH: CGFloat = 36
    private let footerH: CGFloat = 20
    private let cardH: CGFloat = 145
    private let cardGap: CGFloat = 10
    private let introH: CGFloat = 72

    private var contentW: CGFloat { pageSize.width - 2 * margin }
    private var topY: CGFloat { margin + headerH + 10 }

    // MARK: — Public API

    func generate(names: [FirstName]) -> Data {
        let pages = paginate(names)
        let fmt = UIGraphicsPDFRendererFormat()
        fmt.documentInfo = [
            kCGPDFContextTitle as String: "Prénomme — Ma sélection",
            kCGPDFContextAuthor as String: "Prénomme",
            kCGPDFContextCreator as String: "Prénomme App",
        ] as [String: Any]

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: pageSize),
            format: fmt
        )

        return renderer.pdfData { ctx in
            for (idx, chunk) in pages.enumerated() {
                ctx.beginPage()
                drawHeader()
                drawFooter(page: idx + 1, total: pages.count)

                var y = topY
                if idx == 0 {
                    drawIntro(at: y)
                    y += introH + 10
                }
                for name in chunk {
                    drawCard(name, at: y)
                    y += cardH + cardGap
                }
            }
        }
    }

    // MARK: — Pagination (page 1 fits 3 due to intro block)

    func paginate(_ names: [FirstName]) -> [[FirstName]] {
        guard !names.isEmpty else { return [[]] }
        var pages: [[FirstName]] = []
        var tail = names[...]
        let page1Cap = min(3, names.count)
        pages.append(Array(tail.prefix(page1Cap)))
        tail = tail.dropFirst(page1Cap)
        while !tail.isEmpty {
            pages.append(Array(tail.prefix(4)))
            tail = tail.dropFirst(4)
        }
        return pages
    }

    // MARK: — Header

    private func drawHeader() {
        // Badge "Prénomme"
        let badgeRect = CGRect(x: margin, y: margin, width: 88, height: 22)
        sage.setFill()
        UIBezierPath(roundedRect: badgeRect, cornerRadius: 11).fill()

        let badgeAS = NSAttributedString(string: "Prénomme", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: UIColor.white,
        ])
        let bSize = badgeAS.size()
        badgeAS.draw(at: CGPoint(
            x: badgeRect.midX - bSize.width / 2,
            y: badgeRect.midY - bSize.height / 2
        ))

        // Date (right-aligned)
        let dateAS = NSAttributedString(string: formattedDate, attributes: [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.tertiaryLabel,
        ])
        let dSize = dateAS.size()
        dateAS.draw(at: CGPoint(
            x: pageSize.width - margin - dSize.width,
            y: margin + 4
        ))

        // Divider
        let divY = margin + headerH - 6
        let div = UIBezierPath()
        div.move(to: CGPoint(x: margin, y: divY))
        div.addLine(to: CGPoint(x: pageSize.width - margin, y: divY))
        sage.withAlphaComponent(0.25).setStroke()
        div.lineWidth = 0.5
        div.stroke()
    }

    // MARK: — Footer

    private func drawFooter(page: Int, total: Int) {
        let y = pageSize.height - margin - footerH
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.tertiaryLabel,
        ]

        let pageAS = NSAttributedString(string: "\(page) / \(total)", attributes: attrs)
        let pageSize_ = pageAS.size()
        pageAS.draw(at: CGPoint(x: pageSize.width / 2 - pageSize_.width / 2, y: y))

        let creditAS = NSAttributedString(string: "Généré avec Prénomme · prenomme.app", attributes: attrs)
        let creditSize = creditAS.size()
        creditAS.draw(at: CGPoint(x: pageSize.width - margin - creditSize.width, y: y))
    }

    // MARK: — Intro block

    private func drawIntro(at y: CGFloat) {
        let rect = CGRect(x: margin, y: y, width: contentW, height: introH)

        // Cream background
        UIColor(red: 250/255, green: 245/255, blue: 240/255, alpha: 1).setFill()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        path.fill()

        // Sage border 0.5pt
        sage.withAlphaComponent(0.4).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        // Italic centered text
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 3

        let isFrench = Locale.current.language.languageCode?.identifier == "fr"
        let introText = isFrench
            ? "Ces prénoms ont été choisis avec amour, pour un enfant qui n'est pas encore là\nmais qui est déjà présent dans nos cœurs."
            : "These names were chosen with love, for a child not yet here\nbut already present in our hearts."

        NSAttributedString(string: introText, attributes: [
            .font: UIFont.italicSystemFont(ofSize: 12),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: style,
        ]).draw(in: rect.insetBy(dx: 16, dy: 12))
    }

    // MARK: — Name card

    private func drawCard(_ name: FirstName, at y: CGFloat) {
        let rect = CGRect(x: margin, y: y, width: contentW, height: cardH)

        // Background
        UIColor.secondarySystemBackground.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: 10).fill()

        // Left accent strip
        let stripRect = CGRect(x: rect.minX, y: rect.minY, width: 4, height: cardH)
        sage.setFill()
        UIBezierPath(
            roundedRect: stripRect,
            byRoundingCorners: [.topLeft, .bottomLeft],
            cornerRadii: CGSize(width: 4, height: 4)
        ).fill()

        let x = rect.minX + 14
        var cy = rect.minY + 14

        // Name + gender capsule
        let nameAS = NSAttributedString(string: name.name, attributes: [
            .font: UIFont.systemFont(ofSize: 18, weight: .bold),
            .foregroundColor: UIColor.label,
        ])
        nameAS.draw(at: CGPoint(x: x, y: cy))
        drawGenderCapsule(name.gender, at: CGPoint(x: x + nameAS.size().width + 8, y: cy + 2))

        cy += nameAS.size().height + 6

        // Origin
        NSAttributedString(string: name.origin, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel,
        ]).draw(at: CGPoint(x: x, y: cy))
        cy += 18

        // Meaning (truncated area, leaves room for ranks on right)
        NSAttributedString(string: name.meaning, attributes: [
            .font: UIFont.italicSystemFont(ofSize: 11),
            .foregroundColor: UIColor.tertiaryLabel,
        ]).draw(in: CGRect(x: x, y: cy, width: contentW - 28 - 72, height: 36))

        // FR / US ranks (top-right corner)
        var ry = rect.minY + 14
        if let fr = name.popularityRankFR {
            drawRank(label: "FR", value: "#\(fr)", at: CGPoint(x: rect.maxX - 62, y: ry))
            ry += 22
        }
        if let us = name.popularityRankUS {
            drawRank(label: "US", value: "#\(us)", at: CGPoint(x: rect.maxX - 62, y: ry))
        }

        // Bottom separator
        let sep = UIBezierPath()
        sep.move(to: CGPoint(x: rect.minX + 14, y: rect.maxY - 1))
        sep.addLine(to: CGPoint(x: rect.maxX - 14, y: rect.maxY - 1))
        sage.withAlphaComponent(0.3).setStroke()
        sep.lineWidth = 0.5
        sep.stroke()
    }

    // MARK: — Gender capsule

    private func drawGenderCapsule(_ gender: Gender, at origin: CGPoint) {
        let (label, textColor, bgColor): (String, UIColor, UIColor) = switch gender {
        case .female: (
            "Femme",
            UIColor(red: 139/255, green: 74/255, blue: 90/255, alpha: 1),
            UIColor(red: 249/255, green: 232/255, blue: 236/255, alpha: 1)
        )
        case .male: (
            "Homme",
            UIColor(red: 44/255, green: 95/255, blue: 138/255, alpha: 1),
            UIColor(red: 232/255, green: 240/255, blue: 249/255, alpha: 1)
        )
        case .unisex: (
            "Mixte",
            UIColor(red: 61/255, green: 107/255, blue: 61/255, alpha: 1),
            UIColor(red: 232/255, green: 245/255, blue: 232/255, alpha: 1)
        )
        }

        let as_ = NSAttributedString(string: label, attributes: [
            .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
            .foregroundColor: textColor,
        ])
        let size = as_.size()
        let capsuleRect = CGRect(x: origin.x, y: origin.y, width: size.width + 10, height: size.height + 4)

        bgColor.setFill()
        UIBezierPath(roundedRect: capsuleRect, cornerRadius: capsuleRect.height / 2).fill()
        as_.draw(at: CGPoint(x: origin.x + 5, y: origin.y + 2))
    }

    // MARK: — Rank label

    private func drawRank(label: String, value: String, at origin: CGPoint) {
        NSAttributedString(string: label, attributes: [
            .font: UIFont.systemFont(ofSize: 8, weight: .semibold),
            .foregroundColor: UIColor.tertiaryLabel,
        ]).draw(at: origin)

        NSAttributedString(string: value, attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel,
        ]).draw(at: CGPoint(x: origin.x, y: origin.y + 11))
    }

    // MARK: — Helpers

    private var sage: UIColor {
        UIColor(red: 0.59, green: 0.69, blue: 0.49, alpha: 1)
    }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.locale = .current
        return fmt.string(from: Date())
    }
}

import SwiftUI

/// SwiftUI drop-in for Surface 2. Internally hosts `InboxViewController`.
/// When rows change, call `apply` on the UIKit controller.
public struct InboxView: UIViewControllerRepresentable {
    public var dataSource: any InboxDataSource
    public var theme: ConversationTheme
    public var title: String?
    public var actions: InboxActions

    public init(
        dataSource: any InboxDataSource,
        theme: ConversationTheme = .default,
        title: String? = nil,
        actions: InboxActions = InboxActions()
    ) {
        self.dataSource = dataSource
        self.theme = theme
        self.title = title
        self.actions = actions
    }

    public func makeUIViewController(context: Context) -> InboxViewController {
        InboxViewController(dataSource: dataSource, theme: theme, title: title, actions: actions)
    }

    public func updateUIViewController(_ controller: InboxViewController, context: Context) {
        controller.theme = theme
        controller.actions = actions
        if let title {
            controller.titleText = title
        }
    }
}

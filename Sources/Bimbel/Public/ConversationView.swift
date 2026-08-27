import SwiftUI

/// SwiftUI drop-in. Internally hosts `ConversationViewController` (UICollectionView + ChatLayout).
/// When messages change, call `apply` on the UIKit controller — do not rely on pulling arrays.
public struct ConversationView: UIViewControllerRepresentable {
    public var conversationID: ConversationID
    public var dataSource: any ConversationDataSource
    public var theme: ConversationTheme
    public var header: HeaderContent
    public var actions: ConversationActions

    public init(
        conversationID: ConversationID,
        dataSource: any ConversationDataSource,
        theme: ConversationTheme = .default,
        header: HeaderContent,
        actions: ConversationActions = ConversationActions()
    ) {
        self.conversationID = conversationID
        self.dataSource = dataSource
        self.theme = theme
        self.header = header
        self.actions = actions
    }

    public func makeUIViewController(context: Context) -> ConversationViewController {
        ConversationViewController(
            conversationID: conversationID,
            dataSource: dataSource,
            theme: theme,
            header: header,
            actions: actions
        )
    }

    public func updateUIViewController(_ controller: ConversationViewController, context: Context) {
        controller.theme = theme
        controller.header = header
        controller.actions = actions
    }
}

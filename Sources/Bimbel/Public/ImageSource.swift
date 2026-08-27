import Foundation

/// Image payload on Sendable models. There is no `uiImage` case — decode at the view layer.
public enum ImageSource: Hashable, Sendable {
    case asset(String)
    case url(URL)
    case data(Data)
}

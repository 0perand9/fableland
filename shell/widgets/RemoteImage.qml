import QtQuick
import qs.core

// A picture from the web, cropped into a rounded box. Set `url`; the picture
// appears once the daemon has it in its cache (see core/Pictures.qml).
RoundImage {
    id: root

    property string url: ""

    source: Fmt.file(Pictures.paths[url] ?? "")
    onUrlChanged: Pictures.fetch(url)
    Component.onCompleted: Pictures.fetch(url)
}

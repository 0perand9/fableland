import QtQuick
import qs.core

// ListView with the shell's defaults: clipped, no overscroll, thin scroll indicator.
ListView {
    id: root

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    spacing: Theme.px(4)
    highlightMoveDuration: Theme.fast
    highlightResizeDuration: 0
    // Keep a little off-screen so scrolling never shows blanks.
    cacheBuffer: Theme.px(400)

    Scroller {
        parent: root
        target: root
        x: root.width - width - Theme.px(2)
        y: root.visibleArea.yPosition * root.height
    }
}

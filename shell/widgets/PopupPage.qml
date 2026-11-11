import QtQuick
import qs.core

// The root of every popup (popups/<Name>.qml). The popup host gives it a
// frame, animates it in and out and keeps keyboard focus inside it.
//
// Set implicitWidth/implicitHeight (real pixels, so use Theme.px) — the frame
// follows them, animated, if they change while the popup is open.
FocusScope {
    id: root

    // Where on the screen the popup sits:
    //   center | top | top-left | top-right | bottom | left | right | wide
    // "left"/"right" are full-height sidebars, "wide" spans the screen's width.
    property string placement: "center"
    // The argument of `fable toggle <popup> <arg>`, e.g. the tab to show.
    // The host keeps it up to date while the popup is open.
    property string arg: ""
    // Set to false to handle Escape yourself (e.g. to leave a sub-page first).
    property bool closeOnEscape: true

    function close() {
        Ui.close();
    }
}

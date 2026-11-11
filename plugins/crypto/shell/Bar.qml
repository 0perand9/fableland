import QtQuick
import qs.core
import qs.widgets
import qs.bar

// The coins you follow, in the bar: symbol, price and the change over a day.
// Clicking one opens it on CoinGecko.
BarGroup {
    id: root

    property var context: null
    readonly property var state: Daemon.topic("crypto", ({ coins: [], currency: "usd", error: "" }))
    readonly property string sign: ({ usd: "$", eur: "€", gbp: "£", jpy: "¥", inr: "₹", krw: "₩" })[state.currency] ?? ""

    function price(value) {
        const n = Number(value ?? 0);
        const digits = n >= 1000 ? 0 : n >= 1 ? 2 : 4;
        const text = n.toLocaleString(Qt.locale("en_US"), "f", digits);
        return sign !== "" ? sign + text : text + " " + state.currency.toUpperCase();
    }

    visible: state.coins.length > 0
    order: 5
    spacing: Theme.px(2)

    Repeater {
        model: root.state.coins

        Clickable {
            id: coin

            required property var modelData
            readonly property real change: Number(modelData.change ?? 0)

            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: line.implicitWidth + Theme.px(14)
            implicitHeight: Theme.barHeight - Theme.px(10)
            onClicked: Daemon.send("misc.open", { target: "https://www.coingecko.com/en/coins/" + modelData.id })

            Row {
                id: line

                anchors.centerIn: parent
                spacing: Theme.px(5)

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: coin.modelData.symbol
                    size: 11
                    bold: true
                    color: Theme.subtext
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.price(coin.modelData.price)
                    size: 12
                }

                Txt {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (coin.change >= 0 ? "▲" : "▼") + Math.abs(coin.change).toFixed(1) + "%"
                    size: 11
                    color: coin.change >= 0 ? Theme.green : Theme.red
                }
            }
        }
    }
}

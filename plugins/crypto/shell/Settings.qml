import QtQuick
import qs.core
import qs.popups.settings

SettingsPage {
    Section {
        TextRow {
            path: "crypto.coins"
            label: "Coins"
            hint: "CoinGecko ids, separated by commas: the last part of a coin's address there, such as bitcoin or solana."
            placeholder: "bitcoin, ethereum"
            fieldWidth: Theme.px(190)
            keywords: "bitcoin ethereum price ticker"
        }

        ChoiceRow {
            path: "crypto.currency"
            label: "Currency"
            options: [{ value: "usd", label: "USD" }, { value: "eur", label: "EUR" }, { value: "gbp", label: "GBP" }, { value: "jpy", label: "JPY" }, { value: "btc", label: "BTC" }]
            keywords: "dollar euro pound money"
        }

        NumberRow {
            path: "crypto.intervalMinutes"
            label: "Check every"
            hint: "CoinGecko's free service turns away those who ask too often."
            from: 1
            to: 120
            unit: "min"
            keywords: "refresh update interval"
        }

        ActionRow {
            label: "Prices now"
            hint: {
                const state = Daemon.topic("crypto", null);
                if (!state)
                    return "Not asked yet.";
                if (state.error)
                    return "The last try failed: " + state.error;
                return "Last checked at " + new Date(state.updated * 1000).toLocaleTimeString(Qt.locale(), "HH:mm") + ".";
            }
            button: "Refresh"
            icon: Icons.update
            onTriggered: Daemon.send("crypto.refresh")
        }
    }
}

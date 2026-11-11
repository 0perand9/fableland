pragma Singleton
import QtQuick
import Quickshell

// Icon glyphs by name. Every glyph comes from the Nerd Fonts symbol set
// (the comment is its Nerd Fonts name), drawn with `Theme.iconFont` — use the `Icon` widget.
Singleton {

    // general
    readonly property string search: "\u{f0349}"          // md-magnify
    readonly property string close: "\u{f0156}"           // md-close
    readonly property string check: "\u{f012c}"           // md-check
    readonly property string plus: "\u{f0415}"            // md-plus
    readonly property string minus: "\u{f0374}"           // md-minus
    readonly property string chevronLeft: "\u{f0141}"     // md-chevron_left
    readonly property string chevronRight: "\u{f0142}"    // md-chevron_right
    readonly property string chevronUp: "\u{f0143}"       // md-chevron_up
    readonly property string chevronDown: "\u{f0140}"     // md-chevron_down
    readonly property string arrowLeft: "\u{f004d}"       // md-arrow_left
    readonly property string arrowRight: "\u{f0054}"      // md-arrow_right
    readonly property string arrowUp: "\u{f005d}"         // md-arrow_up
    readonly property string arrowDown: "\u{f0045}"       // md-arrow_down
    readonly property string menu: "\u{f035c}"            // md-menu
    readonly property string dots: "\u{f01d8}"            // md-dots_horizontal
    readonly property string dotsVertical: "\u{f01d9}"    // md-dots_vertical
    readonly property string settings: "\u{f0493}"        // md-cog
    readonly property string tune: "\u{f062e}"            // md-tune
    readonly property string help: "\u{f0625}"            // md-help_circle_outline
    readonly property string info: "\u{f02fd}"            // md-information_outline
    readonly property string warning: "\u{f0026}"         // md-alert
    readonly property string error: "\u{f0028}"           // md-alert_circle
    readonly property string refresh: "\u{f0450}"         // md-refresh
    readonly property string sync: "\u{f04e6}"            // md-sync
    readonly property string trash: "\u{f0a7a}"           // md-trash_can_outline
    readonly property string edit: "\u{f03eb}"            // md-pencil
    readonly property string copy: "\u{f018f}"            // md-content_copy
    readonly property string paste: "\u{f0192}"           // md-content_paste
    readonly property string save: "\u{f0193}"            // md-content_save
    readonly property string link: "\u{f0339}"            // md-link_variant
    readonly property string openExternal: "\u{f03cc}"    // md-open_in_new
    readonly property string folder: "\u{f024b}"          // md-folder
    readonly property string folderOpen: "\u{f0770}"      // md-folder_open
    readonly property string file: "\u{f0224}"            // md-file_outline
    readonly property string image: "\u{f02e9}"           // md-image
    readonly property string images: "\u{f02f9}"          // md-image_multiple
    readonly property string video: "\u{f0567}"           // md-video
    readonly property string movie: "\u{f0fce}"           // md-movie_open
    readonly property string eye: "\u{f0208}"             // md-eye
    readonly property string eyeOff: "\u{f0209}"          // md-eye_off
    readonly property string lock: "\u{f033e}"            // md-lock
    readonly property string unlock: "\u{f0fc6}"          // md-lock_open_variant
    readonly property string key: "\u{f0306}"             // md-key
    readonly property string star: "\u{f04ce}"            // md-star
    readonly property string starOutline: "\u{f04d2}"     // md-star_outline
    readonly property string heart: "\u{f02d1}"           // md-heart
    readonly property string pin: "\u{f0403}"             // md-pin
    readonly property string pinOutline: "\u{f0931}"      // md-pin_outline
    readonly property string home: "\u{f02dc}"            // md-home
    readonly property string user: "\u{f0004}"            // md-account
    readonly property string download: "\u{f01da}"        // md-download
    readonly property string upload: "\u{f0552}"          // md-upload
    readonly property string filter: "\u{f0236}"          // md-filter_variant
    readonly property string sort: "\u{f04ba}"            // md-sort
    readonly property string apps: "\u{f003b}"            // md-apps
    readonly property string rocket: "\u{f14de}"          // md-rocket_launch
    readonly property string terminal: "\u{f018d}"        // md-console
    readonly property string code: "\u{f0174}"            // md-code_tags
    readonly property string calculator: "\u{f00ec}"      // md-calculator
    readonly property string web: "\u{f059f}"             // md-web
    readonly property string globe: "\u{f01e7}"           // md-earth
    readonly property string clipboard: "\u{f0a38}"       // md-clipboard_text_outline
    readonly property string palette: "\u{f03d8}"         // md-palette
    readonly property string brush: "\u{f00e3}"           // md-brush
    readonly property string eraser: "\u{f01fe}"          // md-eraser
    readonly property string draw: "\u{f0f49}"            // md-draw
    readonly property string cursor: "\u{f01bf}"          // md-cursor_default_outline
    readonly property string marker: "\u{f0652}"          // md-marker
    readonly property string vectorLine: "\u{f055e}"      // md-vector_line
    readonly property string arrowTopRight: "\u{f005c}"   // md-arrow_top_right
    readonly property string rectangle: "\u{f0e5f}"       // md-rectangle_outline
    readonly property string dotsGrid: "\u{f15fc}"        // md-dots_grid
    readonly property string send: "\u{f048a}"            // md-send
    readonly property string robot: "\u{f06a9}"           // md-robot
    readonly property string sparkle: "\u{f0674}"         // md-creation
    readonly property string grid: "\u{f0570}"            // md-view_grid
    readonly property string list: "\u{f0572}"            // md-view_list
    readonly property string dashboard: "\u{f056e}"       // md-view_dashboard
    readonly property string circle: "\u{f0765}"          // md-circle
    readonly property string circleSmall: "\u{f09df}"     // md-circle_small
    readonly property string circleOutline: "\u{f0766}"   // md-circle_outline
    readonly property string checkCircle: "\u{f05e0}"     // md-check_circle
    readonly property string closeCircle: "\u{f0159}"     // md-close_circle
    readonly property string drag: "\u{f01db}"            // md-drag
    readonly property string expand: "\u{f0616}"          // md-arrow_expand
    readonly property string collapse: "\u{f0615}"        // md-arrow_collapse
    readonly property string fullscreen: "\u{f0293}"      // md-fullscreen
    readonly property string undo: "\u{f054c}"            // md-undo
    readonly property string redo: "\u{f044e}"            // md-redo
    readonly property string translate: "\u{f05ca}"       // md-translate
    readonly property string tag: "\u{f04f9}"             // md-tag
    readonly property string text: "\u{f0284}"            // md-format_text
    readonly property string enter: "\u{f0311}"           // md-keyboard_return
    readonly property string book: "\u{f14f7}"            // md-book_open_variant
    readonly property string compass: "\u{f018c}"         // md-compass_outline

    // devices
    readonly property string keyboard: "\u{f030c}"        // md-keyboard
    readonly property string mouse: "\u{f037d}"           // md-mouse
    readonly property string gamepad: "\u{f0b82}"         // md-controller_classic
    readonly property string headset: "\u{f02ce}"         // md-headset
    readonly property string headphones: "\u{f02cb}"      // md-headphones
    readonly property string speaker: "\u{f04c3}"         // md-speaker
    readonly property string phone: "\u{f011c}"           // md-cellphone
    readonly property string laptop: "\u{f0322}"          // md-laptop
    readonly property string monitor: "\u{f0379}"         // md-monitor
    readonly property string monitors: "\u{f037a}"        // md-monitor_multiple
    readonly property string tv: "\u{f0502}"              // md-television
    readonly property string watch: "\u{f0589}"           // md-watch
    readonly property string printer: "\u{f042a}"         // md-printer
    readonly property string usb: "\u{f0553}"             // md-usb
    readonly property string hdmi: "\u{f0841}"            // md-video_input_hdmi
    readonly property string cpu: "\u{f0ee0}"             // md-cpu_64_bit
    readonly property string chip: "\u{f061a}"            // md-chip
    readonly property string memory: "\u{f035b}"          // md-memory
    readonly property string disk: "\u{f02ca}"            // md-harddisk
    readonly property string gpu: "\u{f08ae}"             // md-expansion_card
    readonly property string thermometer: "\u{f050f}"     // md-thermometer

    // time
    readonly property string clock: "\u{f0150}"           // md-clock_outline
    readonly property string timer: "\u{f051b}"           // md-timer_outline
    readonly property string stopwatch: "\u{f13ab}"       // md-timer
    readonly property string alarm: "\u{f0020}"           // md-alarm
    readonly property string hourglass: "\u{f051f}"       // md-timer_sand
    readonly property string flag: "\u{f023d}"            // md-flag_outline
    readonly property string calendar: "\u{f00ed}"        // md-calendar
    readonly property string calendarToday: "\u{f00f6}"   // md-calendar_today
    readonly property string place: "\u{f034e}"           // md-map_marker
    readonly property string history: "\u{f02da}"         // md-history
    readonly property string notebook: "\u{f082e}"        // md-notebook
    readonly property string note: "\u{f11d7}"            // md-note_text_outline

    // notifications / session
    readonly property string bell: "\u{f009a}"            // md-bell
    readonly property string bellOutline: "\u{f009c}"     // md-bell_outline
    readonly property string bellOff: "\u{f009b}"         // md-bell_off
    readonly property string bellRing: "\u{f009e}"        // md-bell_ring
    readonly property string power: "\u{f0425}"           // md-power
    readonly property string restart: "\u{f0709}"         // md-restart
    readonly property string sleep: "\u{f0904}"           // md-power_sleep
    readonly property string logout: "\u{f0343}"          // md-logout
    readonly property string bolt: "\u{f140b}"            // md-lightning_bolt
    readonly property string plug: "\u{f06a5}"            // md-power_plug
    readonly property string leaf: "\u{f032a}"            // md-leaf
    readonly property string speedometer: "\u{f04c5}"     // md-speedometer
    readonly property string balance: "\u{f05d1}"         // md-scale_balance
    readonly property string battery: "\u{f0079}"         // md-battery
    readonly property string batteryCharging: "\u{f0084}" // md-battery_charging
    readonly property string batteryAlert: "\u{f0083}"    // md-battery_alert
    readonly property string batteryOutline: "\u{f008e}"  // md-battery_outline
    readonly property string brightness: "\u{f00df}"      // md-brightness_6
    readonly property string brightnessLow: "\u{f00de}"   // md-brightness_5
    readonly property string brightnessHigh: "\u{f00e0}"  // md-brightness_7
    readonly property string moon: "\u{f0594}"            // md-weather_night
    readonly property string sun: "\u{f05a8}"             // md-white_balance_sunny

    // audio / media
    readonly property string volumeHigh: "\u{f057e}"      // md-volume_high
    readonly property string volumeMedium: "\u{f0580}"    // md-volume_medium
    readonly property string volumeLow: "\u{f057f}"       // md-volume_low
    readonly property string volumeOff: "\u{f0581}"       // md-volume_off
    readonly property string volumeMute: "\u{f075f}"      // md-volume_mute
    readonly property string mic: "\u{f036c}"             // md-microphone
    readonly property string micOff: "\u{f036d}"          // md-microphone_off
    readonly property string music: "\u{f075a}"           // md-music
    readonly property string musicNote: "\u{f0387}"       // md-music_note
    readonly property string play: "\u{f040a}"            // md-play
    readonly property string pause: "\u{f03e4}"           // md-pause
    readonly property string next: "\u{f04ad}"            // md-skip_next
    readonly property string previous: "\u{f04ae}"        // md-skip_previous
    readonly property string stop: "\u{f04db}"            // md-stop
    readonly property string shuffle: "\u{f049d}"         // md-shuffle
    readonly property string repeat: "\u{f0456}"          // md-repeat
    readonly property string equalizer: "\u{f0ea2}"       // md-equalizer
    readonly property string playlist: "\u{f0cb8}"        // md-playlist_music
    readonly property string album: "\u{f0025}"           // md-album

    // network
    readonly property string wifi: "\u{f05a9}"            // md-wifi
    readonly property string wifiOff: "\u{f05aa}"         // md-wifi_off
    readonly property string wifi1: "\u{f091f}"           // md-wifi_strength_1
    readonly property string wifi2: "\u{f0922}"           // md-wifi_strength_2
    readonly property string wifi3: "\u{f0925}"           // md-wifi_strength_3
    readonly property string wifi4: "\u{f0928}"           // md-wifi_strength_4
    readonly property string wifi0: "\u{f092f}"           // md-wifi_strength_outline
    readonly property string ethernet: "\u{f0200}"        // md-ethernet
    readonly property string lan: "\u{f0317}"             // md-lan
    readonly property string lanOff: "\u{f0319}"          // md-lan_disconnect
    readonly property string router: "\u{f0469}"          // md-router_wireless
    readonly property string bluetooth: "\u{f00af}"       // md-bluetooth
    readonly property string bluetoothOff: "\u{f00b2}"    // md-bluetooth_off
    readonly property string bluetoothConnected: "\u{f00b1}"// md-bluetooth_connect
    readonly property string airplane: "\u{f001d}"        // md-airplane
    readonly property string ip: "\u{f0a60}"              // md-ip_network
    readonly property string frequency: "\u{f095b}"       // md-sine_wave

    // weather
    readonly property string weatherClearDay: "\u{f0599}" // md-weather_sunny
    readonly property string weatherClearNight: "\u{f0594}"// md-weather_night
    readonly property string weatherPartlyDay: "\u{f0595}"// md-weather_partly_cloudy
    readonly property string weatherPartlyNight: "\u{f0f31}"// md-weather_night_partly_cloudy
    readonly property string weatherCloudy: "\u{f0590}"   // md-weather_cloudy
    readonly property string weatherRain: "\u{f0596}"     // md-weather_pouring
    readonly property string weatherStorm: "\u{f0593}"    // md-weather_lightning
    readonly property string weatherSnow: "\u{f0598}"     // md-weather_snowy
    readonly property string weatherFog: "\u{f0591}"      // md-weather_fog
    readonly property string wind: "\u{f059d}"            // md-weather_windy
    readonly property string humidity: "\u{f058e}"        // md-water_percent
    readonly property string umbrella: "\u{f054a}"        // md-umbrella

    // desktop
    readonly property string wallpaper: "\u{f0e09}"       // md-wallpaper
    readonly property string camera: "\u{f0100}"          // md-camera
    readonly property string screenshot: "\u{f0e51}"      // md-monitor_screenshot
    readonly property string crop: "\u{f019e}"            // md-crop
    readonly property string record: "\u{f0ec2}"          // md-record_circle
    readonly property string recordDot: "\u{f044a}"       // md-record
    readonly property string ocr: "\u{f113d}"             // md-text_recognition
    readonly property string qr: "\u{f0433}"              // md-qrcode_scan
    readonly property string update: "\u{f06b0}"          // md-update
    readonly property string pkg:"\u{f03d6}"         // md-package_variant
    readonly property string git: "\u{f02a2}"             // md-git
    readonly property string branch: "\u{f062c}"          // md-source_branch
    readonly property string chart: "\u{f0128}"           // md-chart_bar
    readonly property string chartLine: "\u{f012a}"       // md-chart_line
    readonly property string target: "\u{f04fe}"          // md-target
    readonly property string dnd: "\u{f0376}"             // md-minus_circle
    readonly property string window: "\u{f05af}"          // md-window_maximize
    readonly property string float: "\u{f10ac}"           // md-dock_window
    readonly property string dockTop: "\u{f1513}"         // md-dock_top
    readonly property string keybinds: "\u{f09f9}"        // md-keyboard_settings
    readonly property string nixos: "\uf313"              // linux-nixos
    readonly property string hyprland: "\uf359"           // linux-hyprland
    readonly property string linux: "\uf31a"              // linux-tux

    // ── glyphs that depend on a value ──

    function volume(percent, muted) {
        if (muted) return volumeOff;
        return percent >= 60 ? volumeHigh : percent >= 25 ? volumeMedium : percent > 0 ? volumeLow : volumeMute;
    }

    function wifiSignal(percent) {
        return percent >= 75 ? wifi4 : percent >= 50 ? wifi3 : percent >= 25 ? wifi2 : percent > 5 ? wifi1 : wifi0;
    }

    function batteryLevel(percent, charging) {
        if (charging) return batteryCharging;
        if (percent >= 95) return battery;
        if (percent < 10) return batteryOutline;
        // md-battery_10 … md-battery_90 are consecutive code points.
        return String.fromCodePoint(0xf007a + Math.floor(percent / 10) - 1);
    }

    function brightnessLevel(percent) {
        return percent >= 66 ? brightnessHigh : percent >= 33 ? brightness : brightnessLow;
    }

    // Weather conditions as published by the daemon ("clear-day", "rain", ...).
    function weather(condition) {
        switch (condition) {
        case "clear-day": return weatherClearDay;
        case "clear-night": return weatherClearNight;
        case "partly-day": return weatherPartlyDay;
        case "partly-night": return weatherPartlyNight;
        case "rain": return weatherRain;
        case "storm": return weatherStorm;
        case "snow": return weatherSnow;
        case "fog": return weatherFog;
        default: return weatherCloudy;
        }
    }

    // Device kinds as published in `power.peripherals`, `bt.devices` and `audio.sinks`.
    function device(kind, fallback) {
        switch (kind) {
        case "mouse": return mouse;
        case "keyboard": return keyboard;
        case "gamepad": return gamepad;
        case "headset": return headset;
        case "headphone": case "headphones": return headphones;
        case "speaker": return speaker;
        case "phone": return phone;
        case "computer": return laptop;
        case "watch": return watch;
        case "tv": case "hdmi": return tv;
        case "usb": return usb;
        case "bluetooth": return bluetooth;
        default: return fallback ?? circleSmall;
        }
    }
}

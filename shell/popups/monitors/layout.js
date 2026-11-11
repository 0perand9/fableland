.pragma library

// The geometry of a monitor layout and the modes a monitor offers.
//
// A monitor is a plain object { name, width, height, refreshRate, x, y, scale,
// transform }: `width`/`height` are the pixels of its mode and `x`/`y` its
// corner in the compositor's layout, where it takes up those pixels turned by
// `transform` and divided by `scale`.

// Rectangles closer than this (in layout pixels) count as touching.
const EPSILON = 0.5;
// Hyprland only accepts scales in steps of 1/120 that divide the mode evenly.
const SCALE_STEPS = 120;
// The range the scale slider covers (`var`, because QML cannot see a library's constants).
var MIN_SCALE = 0.5, MAX_SCALE = 3;

const RESOLUTION_NAMES = {
    "7680x4320": "8K", "5120x2880": "5K", "5120x1440": "DQHD", "3840x2160": "4K", "3840x1600": "UW4K",
    "3440x1440": "UWQHD", "2560x1600": "WQXGA", "2560x1440": "QHD", "2560x1080": "UWFHD",
    "1920x1200": "WUXGA", "1920x1080": "FHD", "1600x900": "HD+", "1366x768": "WXGA", "1280x720": "HD"
};

// ── rectangles ──

// The area a monitor covers in the layout.
function rect(m) {
    const turned = m.transform % 2 === 1;
    return { x: m.x, y: m.y, w: (turned ? m.height : m.width) / m.scale, h: (turned ? m.width : m.height) / m.scale };
}

function overlap(a, b) {
    return a.x < b.x + b.w - EPSILON && a.x + a.w > b.x + EPSILON && a.y < b.y + b.h - EPSILON && a.y + a.h > b.y + EPSILON;
}

// Sharing a stretch of edge (a corner alone does not count: the pointer could not cross).
function touching(a, b) {
    const sharedX = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
    const sharedY = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    const besideX = Math.abs(a.x + a.w - b.x) < EPSILON || Math.abs(b.x + b.w - a.x) < EPSILON;
    const besideY = Math.abs(a.y + a.h - b.y) < EPSILON || Math.abs(b.y + b.h - a.y) < EPSILON;
    return (besideX && sharedY > EPSILON) || (besideY && sharedX > EPSILON);
}

// The rectangle around every monitor.
function bounds(monitors) {
    let left = Infinity, top = Infinity, right = -Infinity, bottom = -Infinity;
    for (const m of monitors) {
        const r = rect(m);
        left = Math.min(left, r.x);
        top = Math.min(top, r.y);
        right = Math.max(right, r.x + r.w);
        bottom = Math.max(bottom, r.y + r.h);
    }
    return { x: left, y: top, w: right - left, h: bottom - top };
}

// ── arranging ──

// Where a rectangle of `size` can sit against the rectangle `anchor`: one spot
// per edge, as close to `wanted` as that edge allows. Along the edge it snaps
// (within `snap`) to where the two line up at the start, the end or the centre.
function spotsAround(anchor, size, wanted, snap) {
    const along = (value, low, high, stops) => {
        const clamped = Math.max(low, Math.min(high, value));
        let best = clamped, reach = snap;
        for (const stop of stops) {
            if (Math.abs(clamped - stop) <= reach) {
                best = stop;
                reach = Math.abs(clamped - stop);
            }
        }
        return best;
    };
    // Keep a quarter of the shorter side in contact, so the two never meet at a corner only.
    const keepX = Math.min(size.w, anchor.w) / 4, keepY = Math.min(size.h, anchor.h) / 4;
    const x = along(wanted.x, anchor.x - size.w + keepX, anchor.x + anchor.w - keepX,
                    [anchor.x, anchor.x + anchor.w - size.w, anchor.x + (anchor.w - size.w) / 2]);
    const y = along(wanted.y, anchor.y - size.h + keepY, anchor.y + anchor.h - keepY,
                    [anchor.y, anchor.y + anchor.h - size.h, anchor.y + (anchor.h - size.h) / 2]);
    return [
        { x: anchor.x - size.w, y: y }, { x: anchor.x + anchor.w, y: y },
        { x: x, y: anchor.y - size.h }, { x: x, y: anchor.y + anchor.h }
    ];
}

// The spot nearest to `wanted` where a rectangle of `size` touches one of the
// `fixed` rectangles and overlaps none; null if they leave no room.
function glue(size, wanted, fixed, snap) {
    let best = null, bestDistance = Infinity;
    for (const anchor of fixed) {
        for (const spot of spotsAround(anchor, size, wanted, snap)) {
            const placed = { x: spot.x, y: spot.y, w: size.w, h: size.h };
            if (fixed.some(other => other !== anchor && overlap(placed, other)))
                continue;
            const distance = Math.hypot(spot.x - wanted.x, spot.y - wanted.y);
            if (distance < bestDistance) {
                best = spot;
                bestDistance = distance;
            }
        }
    }
    return best;
}

// Shift the layout so that its top left corner is at 0,0 (what Hyprland expects), on whole pixels.
function normalise(monitors) {
    if (monitors.length === 0)
        return monitors;
    const b = bounds(monitors);
    return monitors.map(m => Object.assign({}, m, { x: Math.round(m.x - b.x), y: Math.round(m.y - b.y) }));
}

// Make the layout whole again after `anchorName` moved or changed size: the
// anchor stays, and every monitor that now overlaps or has lost contact is
// pushed to the nearest free spot against the ones already in place.
function settle(monitors, anchorName) {
    const anchor = monitors.find(m => m.name === anchorName) ?? monitors[0];
    if (!anchor)
        return monitors;
    const centre = r => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });
    const from = centre(rect(anchor));
    const distance = m => m === anchor ? -1 : Math.hypot(centre(rect(m)).x - from.x, centre(rect(m)).y - from.y);
    const placed = [], spots = {};
    for (const m of monitors.slice().sort((a, b) => distance(a) - distance(b))) {
        let r = rect(m);
        if (placed.length > 0 && (placed.some(p => overlap(r, p)) || !placed.some(p => touching(r, p)))) {
            const spot = glue(r, r, placed, 0);
            if (spot)
                r = { x: spot.x, y: spot.y, w: r.w, h: r.h };
        }
        placed.push(r);
        spots[m.name] = r;
    }
    return normalise(monitors.map(m => Object.assign({}, m, { x: spots[m.name].x, y: spots[m.name].y })));
}

// ── state ──

// What the daemon reports about its monitors, as an editable layout.
function seed(live) {
    return normalise(live.map(m => ({
        name: m.name, width: m.width, height: m.height, refreshRate: m.refreshRate,
        x: m.x, y: m.y, scale: cleanScale(m.width, m.height, m.scale), transform: m.transform
    })));
}

// The layout as `hypr.applyMonitors` takes it.
function request(monitors) {
    return monitors.map(m => ({
        name: m.name, width: m.width, height: m.height, refreshRate: m.refreshRate,
        x: Math.round(m.x), y: Math.round(m.y), scale: m.scale, transform: m.transform
    }));
}

function sameNames(a, b) {
    return a.length === b.length && a.every(m => b.some(other => other.name === m.name));
}

// Whether two layouts would look the same once applied.
function same(a, b) {
    return sameNames(a, b) && a.every(m => {
        const o = b.find(other => other.name === m.name);
        return m.width === o.width && m.height === o.height && Math.abs(m.refreshRate - o.refreshRate) < 0.05
            && Math.round(m.x) === Math.round(o.x) && Math.round(m.y) === Math.round(o.y)
            && Math.abs(m.scale - o.scale) < 0.001 && m.transform === o.transform;
    });
}

// ── modes ──

// A monitor's modes ("3840x2160@60.00Hz", …) by resolution, largest first:
// [{ key: "3840x2160", width, height, rates: [240, 119.88, 60] }]. The mode in
// use is always among them, even when the monitor does not advertise it.
function resolutions(monitor) {
    const found = {};
    const add = (width, height, rate) => {
        const key = width + "x" + height;
        const entry = found[key] ?? (found[key] = { key: key, width: width, height: height, rates: [] });
        if (!entry.rates.some(other => Math.abs(other - rate) < 0.05))
            entry.rates.push(rate);
    };
    for (const mode of monitor.modes ?? []) {
        const parts = /^(\d+)x(\d+)@([\d.]+)/.exec(mode);
        if (parts)
            add(Number(parts[1]), Number(parts[2]), Number(parts[3]));
    }
    const current = found[monitor.width + "x" + monitor.height];
    if (!current || !current.rates.some(rate => Math.abs(rate - monitor.refreshRate) < 0.5))
        add(monitor.width, monitor.height, Math.round(monitor.refreshRate * 100) / 100);
    const list = Object.values(found);
    for (const entry of list)
        entry.rates.sort((a, b) => b - a);
    return list.sort((a, b) => b.width * b.height - a.width * a.height || b.width - a.width);
}

// Index of the rate closest to `rate`.
function nearestRate(rates, rate) {
    let best = 0;
    for (let i = 1; i < rates.length; i++) {
        if (Math.abs(rates[i] - rate) < Math.abs(rates[best] - rate))
            best = i;
    }
    return best;
}

// "4K" for the resolutions people know by name, otherwise the aspect ratio.
function resolutionTag(width, height) {
    const name = RESOLUTION_NAMES[width + "x" + height];
    if (name)
        return name;
    const gcd = (a, b) => b === 0 ? a : gcd(b, a % b);
    const unit = gcd(width, height);
    const ratio = width / unit + ":" + height / unit;
    return ratio === "8:5" ? "16:10" : Math.abs(width / height - 21 / 9) < 0.08 ? "21:9" : ratio;
}

// ── scale ──

function scaleFits(width, height, steps) {
    return steps > 0 && (width * SCALE_STEPS) % steps === 0 && (height * SCALE_STEPS) % steps === 0;
}

// The scale closest to `wanted` that Hyprland accepts for a mode: a multiple
// of 1/120 that leaves a whole number of logical pixels in both directions.
function cleanScale(width, height, wanted) {
    const low = Math.ceil(MIN_SCALE * SCALE_STEPS), high = Math.floor(MAX_SCALE * SCALE_STEPS);
    const start = Math.max(low, Math.min(high, Math.round(wanted * SCALE_STEPS)));
    for (let offset = 0; offset <= high - low; offset++) {
        for (const steps of [start - offset, start + offset]) {
            if (steps >= low && steps <= high && scaleFits(width, height, steps))
                return steps / SCALE_STEPS;
        }
    }
    return wanted;
}

// The next acceptable scale above (`way` > 0) or below `scale`; `scale` itself at the end of the range.
function nextScale(width, height, scale, way) {
    const low = Math.ceil(MIN_SCALE * SCALE_STEPS), high = Math.floor(MAX_SCALE * SCALE_STEPS);
    for (let steps = Math.round(scale * SCALE_STEPS) + way; steps >= low && steps <= high; steps += way) {
        if (scaleFits(width, height, steps))
            return steps / SCALE_STEPS;
    }
    return scale;
}

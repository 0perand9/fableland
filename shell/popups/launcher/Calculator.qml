import QtQuick

// The launcher's calculator: + - * / % ^, brackets, percentages, a few
// functions and constants. Parsed by hand (recursive descent) — what the user
// types is never handed to eval().
QtObject {
    id: root

    readonly property var constants: new Map([["pi", Math.PI], ["tau", 2 * Math.PI], ["e", Math.E]])
    readonly property var functions: new Map([
        ["sqrt", Math.sqrt], ["cbrt", Math.cbrt], ["abs", Math.abs], ["round", Math.round], ["floor", Math.floor], ["ceil", Math.ceil],
        ["sin", Math.sin], ["cos", Math.cos], ["tan", Math.tan], ["asin", Math.asin], ["acos", Math.acos], ["atan", Math.atan],
        ["ln", Math.log], ["log", Math.log10], ["log2", Math.log2], ["exp", Math.exp]
    ])

    // Numbers become numbers; names, operators and brackets stay strings.
    // Null when the text holds anything else.
    function tokenize(text) {
        const pattern = /\s*(?:((?:\d+(?:\.\d*)?|\.\d+)(?:e[+-]?\d+)?)|([a-z][a-z0-9]*)|(\*\*|[-+*\/%^()]))\s*/y;
        const source = text.toLowerCase();
        const tokens = [];
        while (pattern.lastIndex < source.length) {
            const match = pattern.exec(source);
            if (!match)
                return null;
            tokens.push(match[1] !== undefined ? parseFloat(match[1]) : (match[2] ?? match[3]));
        }
        return tokens;
    }

    // The result of `text` as a string, or "" when it is not a complete
    // expression with a finite value. Unless `explicit`, something must
    // actually be computed: "2048" and "-5" are searches, not sums.
    function evaluate(text, explicit) {
        const tokens = tokenize(text);
        if (!tokens || tokens.length === 0)
            return "";
        let at = 0, operations = 0;
        const take = token => tokens[at] === token && (at++, true);
        // What tells "10 % 3" (modulo) from "10% + 3" (a percentage).
        const startsOperand = token => typeof token === "number" || token === "(" || constants.has(token) || functions.has(token);

        function sum() {
            let value = product();
            while (tokens[at] === "+" || tokens[at] === "-") {
                const sign = tokens[at++] === "+" ? 1 : -1;
                const from = at;
                const right = product();
                // "200 + 10%" adds ten percent of the 200, as a pocket calculator does.
                const ofValue = at - from === 2 && tokens[at - 1] === "%";
                value += sign * (ofValue ? value * right : right);
                operations++;
            }
            return value;
        }

        function product() {
            let value = signed();
            for (;;) {
                if (take("*"))
                    value *= signed();
                else if (take("/"))
                    value /= signed();
                else if (take("%"))
                    value %= signed();
                else
                    return value;
                operations++;
            }
        }

        function signed() {
            if (take("-"))
                return -signed();
            return take("+") ? signed() : power();
        }

        // Binds tighter than a sign on its left (-2^2 = -4) and groups to the right (2^3^2 = 2^9).
        function power() {
            const base = percentage();
            if (!take("^") && !take("**"))
                return base;
            operations++;
            return Math.pow(base, signed());
        }

        function percentage() {
            let value = operand();
            while (tokens[at] === "%" && !startsOperand(tokens[at + 1])) {
                at++;
                operations++;
                value /= 100;
            }
            return value;
        }

        function operand() {
            const token = tokens[at++];
            if (typeof token === "number")
                return token;
            if (constants.has(token))
                return constants.get(token);
            const bracketed = token === "(" || (functions.has(token) && take("("));
            if (!bracketed)
                return NaN;
            const inner = sum();
            if (!take(")"))
                return NaN;
            if (token === "(")
                return inner;
            operations++;
            return functions.get(token)(inner);
        }

        const value = sum();
        if (at !== tokens.length || !isFinite(value) || !(explicit || operations > 0))
            return "";
        // Twelve significant digits hide binary noise: 0.1 + 0.2 is 0.3.
        return String(parseFloat(value.toPrecision(12)));
    }
}

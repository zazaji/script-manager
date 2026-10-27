// ScriptManager/Core/FormulaEvaluator.swift
import Foundation

/// 启动器公式计算（`=` 前缀触发）。
/// 架构级约束：纯函数求值器——无状态、无 IO、不依赖 UI 与 ViewModel；
/// 每次按键都会被 LauncherViewModel.filterItems() 调用，必须保持微秒级开销。
///
/// 语法支持：
/// - 四则运算 `+ - * /`、幂 `^` 或 `**`（右结合）、阶乘 `!`（后缀）、一元正负号、括号
/// - 隐式乘法：`2pi`、`(1+2)(3+4)`、`2(3+4)`
/// - 百分比后缀：`50%` == 0.5（取模因此只能用 `mod(a,b)`，避免 `10%3` 的歧义）
/// - 进制字面量：十六进制 `0xFF`、二进制 `0b1010`、八进制 `0o17`
/// - 角度：常量 `deg`（1° 的弧度值）与符号 `°`——`sin(30°)`；转换函数 `deg2rad`/`rad2deg`
/// - 常量：`pi/π`、`e`、`tau`、`phi`、`deg`；函数与常量名大小写不敏感
/// - 函数（40+）：三角/反三角（含双曲、atan2）、sqrt/cbrt/root、ln/log(可选底数)/log2、
///   exp/abs/sign/round/floor/ceil/trunc、min/max/hypot/pow/mod、gcd/lcm/ncr/npr、
///   gamma/lgamma、deg2rad/rad2deg（函数后括号可省略：`sqrt9` == `sqrt(9)`）
/// - 全角/数学符号归一化：＝ ＋ － × ÷ （ ） ， ％ ． ０-９ π √ ² ³ °
public enum FormulaEvaluator {

    public enum FormulaError: Error, Equatable {
        case emptyExpression
        case unexpectedCharacter(Character)
        case unexpectedEnd
        case trailingContent
        case unknownFunction(String)
        case invalidNumber(String)
        case invalidArgumentCount(String)
        case divisionByZero
        case factorialDomain
        case mathError
    }

    private enum Token: Equatable {
        case number(Double)
        case identifier(String)
        case op(Character)
    }

    // MARK: - 对外入口

    public static func evaluate(_ rawExpression: String) throws -> Double {
        let normalized = normalize(rawExpression)
        guard !normalized.isEmpty else { throw FormulaError.emptyExpression }

        var tokens: [Token] = []
        var index = normalized.startIndex
        while index < normalized.endIndex {
            if normalized[index] == " " || normalized[index] == "\t" {
                index = normalized.index(after: index)
                continue
            }
            let (token, next) = try tokenize(normalized, from: index)
            tokens.append(token)
            index = next
        }
        guard !tokens.isEmpty else { throw FormulaError.emptyExpression }

        var parser = Parser(tokens: tokens)
        let value = try parser.parseExpression()
        try parser.expectEnd()
        guard value.isFinite else { throw FormulaError.mathError }
        return value
    }

    /// 结果展示格式：12 位有效数字抹平浮点噪声（0.1+0.2 → 0.3），指数形式去掉多余的 +
    public static func format(_ value: Double) -> String {
        guard value.isFinite else { return "NaN" }
        if value == 0 { return "0" } // 同时吞掉 -0
        return String(format: "%.12g", value)
            .replacingOccurrences(of: "e+", with: "e")
    }

    // MARK: - 归一化与分词

    /// 中文输入法产生的全角字符与常见数学符号统一映射为 ASCII 语法符号
    private static func normalize(_ raw: String) -> String {
        var out = ""
        out.reserveCapacity(raw.count)
        for ch in raw {
            switch ch {
            case "＝": out.append("=")
            case "＋": out.append("+")
            case "－", "−", "–", "—": out.append("-")
            case "×", "·": out.append("*")
            case "÷": out.append("/")
            case "（": out.append("(")
            case "）": out.append(")")
            case "，": out.append(",")
            case "％": out.append("%")
            case "．": out.append(".")
            case "０"..."９":
                // 全角数字与 ASCII 数字码差固定 0xFEE0
                if let scalar = ch.unicodeScalars.first, let ascii = UnicodeScalar(scalar.value - 0xFEE0) {
                    out.append(Character(ascii))
                }
            case "π": out.append("pi")
            case "√": out.append("sqrt")
            case "²": out.append("^2")
            case "³": out.append("^3")
            case "°": out.append("*deg")
            case "。": break // 中文句末标点，静默吞掉
            default: out.append(ch)
            }
        }
        // `**` 幂等价写法归一为 ^（避免分词后产生两个相邻乘号导致解析错误）
        while out.contains("**") {
            out = out.replacingOccurrences(of: "**", with: "^")
        }
        return out
    }

    private static func tokenize(_ s: String, from start: String.Index) throws -> (Token, String.Index) {
        let ch = s[start]
        if isASCIIDigit(ch) || ch == "." {
            return try tokenizeNumber(s, from: start)
        }
        if ch.isLetter {
            var end = start
            while end < s.endIndex, s[end].isLetter || isASCIIDigit(s[end]) {
                end = s.index(after: end)
            }
            // 函数/常量名大小写不敏感，统一按小写匹配（log2 这类带数字的名字由此并入同一标识符）
            return (.identifier(String(s[start..<end]).lowercased()), end)
        }
        switch ch {
        case "+", "-", "*", "/", "%", "^", "!", "(", ")", ",":
            return (.op(ch), s.index(after: start))
        default:
            throw FormulaError.unexpectedCharacter(ch)
        }
    }

    private static func tokenizeNumber(_ s: String, from start: String.Index) throws -> (Token, String.Index) {
        if let radix = try tokenizeRadix(s, from: start) { return radix }
        var end = start
        var seenDot = false
        while end < s.endIndex {
            let c = s[end]
            if isASCIIDigit(c) {
                end = s.index(after: end)
            } else if c == "." && !seenDot {
                seenDot = true
                end = s.index(after: end)
            } else {
                break
            }
        }
        // 科学计数法：e/E 后必须跟数字（可带符号）才算指数，否则 e 留给常量（如 "2e" == 2*常量e）
        if end < s.endIndex, s[end] == "e" || s[end] == "E" {
            var expEnd = s.index(after: end)
            if expEnd < s.endIndex, s[expEnd] == "+" || s[expEnd] == "-" {
                expEnd = s.index(after: expEnd)
            }
            if expEnd < s.endIndex, isASCIIDigit(s[expEnd]) {
                while expEnd < s.endIndex, isASCIIDigit(s[expEnd]) {
                    expEnd = s.index(after: expEnd)
                }
                end = expEnd
            }
        }
        let text = String(s[start..<end])
        guard let value = Double(text) else { throw FormulaError.invalidNumber(text) }
        return (.number(value), end)
    }

    private static func isASCIIDigit(_ ch: Character) -> Bool {
        ch.isASCII && ch.isNumber
    }

    /// 进制字面量：0xFF / 0b1010 / 0o17（前缀大小写均可）。非进制前缀返回 nil 走十进制解析；
    /// 直接在 Double 上累加而不是 Int 转换，超长十六进制不崩溃、仅按 Double 精度截断
    private static func tokenizeRadix(_ s: String, from start: String.Index) throws -> (Token, String.Index)? {
        guard s[start] == "0" else { return nil }
        let prefixIndex = s.index(after: start)
        guard prefixIndex < s.endIndex else { return nil }
        let radix: Int
        switch s[prefixIndex] {
        case "x", "X": radix = 16
        case "b", "B": radix = 2
        case "o", "O": radix = 8
        default: return nil
        }
        var i = s.index(after: prefixIndex)
        var value = 0.0
        var count = 0
        while i < s.endIndex, let digit = s[i].hexDigitValue, digit < radix {
            value = value * Double(radix) + Double(digit)
            i = s.index(after: i)
            count += 1
        }
        guard count > 0 else { throw FormulaError.invalidNumber(String(s[start...prefixIndex])) }
        return (.number(value), i)
    }

    /// 标识符拆分回退："sqrt9" → sqrt(9)、"e2" → e*2。
    /// 分词会把字母后紧跟的数字并入同一标识符，精确匹配失败时按已知名称做最长前缀拆分，
    /// 仅接受纯数字后缀（"sqrt4pi" 这类组合仍报未知函数）；无意义结果（NaN）同样视为未命中
    private static func resolveIdentifierWithNumberSuffix(_ name: String) -> Double? {
        var candidates: [(prefix: String, make: (Double) -> Double)] = []
        for (funcName, signature) in FormulaEvaluator.functions
        where signature.arity.contains(1) && name.hasPrefix(funcName) {
            candidates.append((funcName, { signature.apply([$0]) }))
        }
        for (constantName, value) in FormulaEvaluator.constants where name.hasPrefix(constantName) {
            candidates.append((constantName, { $0 * value }))
        }
        guard let best = candidates.max(by: { $0.prefix.count < $1.prefix.count }),
              let number = Double(name.dropFirst(best.prefix.count)) else { return nil }
        let result = best.make(number)
        return result.isFinite ? result : nil
    }

    // MARK: - 递归下降解析
    // 文法（优先级从低到高）：expr(+,-) → term(*,/,隐式乘) → unary(正负号) → power(^,右结合)
    //                        → postfix(!,%) → primary(数字/常量/函数/括号)

    private struct Parser {
        let tokens: [Token]
        var pos = 0

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while case .op(let op)? = peek(), op == "+" || op == "-" {
                _ = advance()
                let rhs = try parseTerm()
                value = op == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func parseTerm() throws -> Double {
            var value = try parseUnary()
            while true {
                if case .op(let op)? = peek(), op == "*" || op == "/" {
                    _ = advance()
                    let rhs = try parseUnary()
                    if op == "*" {
                        value *= rhs
                    } else {
                        guard rhs != 0 else { throw FormulaError.divisionByZero }
                        value /= rhs
                    }
                } else if startsValue(peek()) {
                    // 隐式乘法：2pi、2(3+4)、(1+2)(3+4)
                    value *= try parseUnary()
                } else {
                    break
                }
            }
            return value
        }

        private mutating func parseUnary() throws -> Double {
            if case .op(let op)? = peek(), op == "-" || op == "+" {
                _ = advance()
                let value = try parseUnary()
                return op == "-" ? -value : value
            }
            return try parsePower()
        }

        private mutating func parsePower() throws -> Double {
            let base = try parsePostfix()
            if case .op("^")? = peek() {
                _ = advance()
                // 右结合：2^3^2 == 2^(3^2)；-2^2 由 parseUnary 处理为 -(2^2)
                let exponent = try parseUnary()
                if base == 0 && exponent < 0 { throw FormulaError.divisionByZero }
                let result = pow(base, exponent)
                guard result.isFinite else { throw FormulaError.mathError }
                return result
            }
            return base
        }

        private mutating func parsePostfix() throws -> Double {
            var value = try parsePrimary()
            while case .op(let op)? = peek() {
                if op == "!" {
                    _ = advance()
                    value = try Self.factorial(value)
                } else if op == "%" {
                    _ = advance()
                    value /= 100 // 百分比后缀：50% == 0.5
                } else {
                    break
                }
            }
            return value
        }

        private mutating func parsePrimary() throws -> Double {
            guard let token = advance() else { throw FormulaError.unexpectedEnd }
            switch token {
            case .number(let value):
                return value
            case .op("("):
                let value = try parseExpression()
                try expect(")")
                return value
            case .identifier(let name):
                if let constant = FormulaEvaluator.constants[name] { return constant }
                if let signature = FormulaEvaluator.functions[name] {
                    let args = try parseArguments()
                    guard signature.arity.contains(args.count) else {
                        throw FormulaError.invalidArgumentCount(name)
                    }
                    let result = signature.apply(args)
                    guard result.isFinite else { throw FormulaError.mathError }
                    return result
                }
                if let value = FormulaEvaluator.resolveIdentifierWithNumberSuffix(name) { return value }
                throw FormulaError.unknownFunction(name)
            default:
                // 值的位置上出现 ")" "," 等符号
                throw FormulaError.unexpectedEnd
            }
        }

        private mutating func parseArguments() throws -> [Double] {
            guard case .op("(")? = peek() else {
                // 括号省略：sqrt9 == sqrt(9)，参数取下一个幂级因子（不越过 + - 的优先级）
                return [try parsePower()]
            }
            _ = advance()
            var args: [Double] = []
            if case .op(")")? = peek() {
                _ = advance()
                return args // 空参数交给 arity 校验报错
            }
            args.append(try parseExpression())
            while case .op(",")? = peek() {
                _ = advance()
                args.append(try parseExpression())
            }
            try expect(")")
            return args
        }

        private mutating func expect(_ ch: Character) throws {
            guard case .op(let c)? = advance(), c == ch else {
                throw FormulaError.unexpectedEnd
            }
        }

        mutating func expectEnd() throws {
            guard pos >= tokens.count else { throw FormulaError.trailingContent }
        }

        @discardableResult
        private mutating func advance() -> Token? {
            defer { pos += 1 }
            return pos < tokens.count ? tokens[pos] : nil
        }

        private func peek() -> Token? {
            pos < tokens.count ? tokens[pos] : nil
        }

        private func startsValue(_ token: Token?) -> Bool {
            switch token {
            case .number, .identifier, .op("("): return true
            default: return false
            }
        }

        private static func factorial(_ n: Double) throws -> Double {
            guard n.rounded() == n, n >= 0, n <= 170 else { throw FormulaError.factorialDomain }
            var result = 1.0
            var i = 2.0
            while i <= n {
                result *= i
                i += 1
            }
            return result
        }
    }

    // MARK: - 常量与函数表

    private static let constants: [String: Double] = [
        "pi": .pi,
        "e": M_E,
        "tau": 2 * .pi,
        "phi": (1 + sqrt(5)) / 2,
        "deg": .pi / 180, // 1° 的弧度值：sin(30°) → sin(30*deg)
    ]

    private static let functions: [String: (arity: ClosedRange<Int>, apply: ([Double]) -> Double)] = [
        "sin": (1...1, { sin($0[0]) }),
        "cos": (1...1, { cos($0[0]) }),
        "tan": (1...1, { tan($0[0]) }),
        "asin": (1...1, { asin($0[0]) }),
        "acos": (1...1, { acos($0[0]) }),
        "atan": (1...1, { atan($0[0]) }),
        "atan2": (2...2, { atan2($0[0], $0[1]) }),
        "sinh": (1...1, { sinh($0[0]) }),
        "cosh": (1...1, { cosh($0[0]) }),
        "tanh": (1...1, { tanh($0[0]) }),
        "asinh": (1...1, { asinh($0[0]) }),
        "acosh": (1...1, { acosh($0[0]) }),
        "atanh": (1...1, { atanh($0[0]) }),
        "sqrt": (1...1, { sqrt($0[0]) }),
        "cbrt": (1...1, { cbrt($0[0]) }),
        "root": (2...2, { args in
            let (x, n) = (args[0], args[1])
            guard n != 0 else { return .nan }
            if x < 0 {
                // 奇次方根允许负底数：root(-27, 3) == -3
                return n.truncatingRemainder(dividingBy: 2) == 1 ? -pow(-x, 1 / n) : .nan
            }
            return pow(x, 1 / n)
        }),
        "ln": (1...1, { log($0[0]) }),
        "log": (1...2, { args in
            // 计算器惯例：log 为常用对数，自然对数用 ln；log(8, 2) 允许显式底数
            args.count == 1
                ? log10(args[0])
                : (log(args[1]) == 0 ? .nan : log(args[0]) / log(args[1]))
        }),
        "log2": (1...1, { log2($0[0]) }),
        "exp": (1...1, { exp($0[0]) }),
        "abs": (1...1, { abs($0[0]) }),
        "sign": (1...1, { args in
            let x = args[0]
            return x > 0 ? 1 : (x < 0 ? -1 : 0)
        }),
        "round": (1...1, { $0[0].rounded() }),
        "floor": (1...1, { floor($0[0]) }),
        "ceil": (1...1, { ceil($0[0]) }),
        "trunc": (1...1, { $0[0].rounded(.towardZero) }),
        "gamma": (1...1, { tgamma($0[0]) }),
        "lgamma": (1...1, { lgamma($0[0]) }),
        "gcd": (2...Int.max, { args in
            var g = 0
            for x in args {
                guard let v = FormulaEvaluator.toInt(x) else { return .nan }
                g = FormulaEvaluator.gcdPair(g, abs(v))
            }
            return Double(g)
        }),
        "lcm": (2...Int.max, { args in
            var l = 1
            for x in args {
                guard let v = FormulaEvaluator.toInt(x), v != 0 else { return .nan }
                l = l / FormulaEvaluator.gcdPair(l, abs(v)) * abs(v)
            }
            return Double(l)
        }),
        "ncr": (2...2, { args in
            // 组合数 C(n,r)：中间过程保持整数，循环上限护栏防超大输入卡死
            guard let n = FormulaEvaluator.toInt(args[0]), let r = FormulaEvaluator.toInt(args[1]),
                  n >= 0, r >= 0, r <= 10_000_000 else { return .nan }
            guard r <= n else { return 0 }
            let k = min(r, n - r)
            var result = 1.0
            for i in 1...k {
                result = result * Double(n - k + i) / Double(i)
            }
            return result
        }),
        "npr": (2...2, { args in
            guard let n = FormulaEvaluator.toInt(args[0]), let r = FormulaEvaluator.toInt(args[1]),
                  n >= 0, r >= 0, r <= 10_000_000 else { return .nan }
            var result = 1.0
            for i in 0..<r {
                result *= Double(n - i)
            }
            return result
        }),
        "min": (2...Int.max, { $0.min() ?? .nan }),
        "max": (2...Int.max, { $0.max() ?? .nan }),
        "hypot": (2...Int.max, { args in args.dropFirst().reduce(args[0]) { hypot($0, $1) } }),
        "pow": (2...2, { pow($0[0], $0[1]) }),
        "mod": (2...2, { $0[0].truncatingRemainder(dividingBy: $0[1]) }),
        "deg2rad": (1...1, { $0[0] * .pi / 180 }),
        "rad2deg": (1...1, { $0[0] * 180 / .pi }),
    ]

    /// 整数护栏：gcd/lcm/ncr/npr 需要整数参数；先验证整数性与 2^53 精度上限，
    /// 避免 Int(x) 对超大 Double 直接运行时崩溃
    private static func toInt(_ x: Double) -> Int? {
        guard x.rounded() == x, abs(x) <= 9_007_199_254_740_992 else { return nil }
        return Int(x)
    }

    private static func gcdPair(_ a: Int, _ b: Int) -> Int {
        var a = a
        var b = b
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return a
    }
}

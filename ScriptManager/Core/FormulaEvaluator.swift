// ScriptManager/Core/FormulaEvaluator.swift
import Foundation

/// 启动器公式计算（`=` 前缀触发）。
/// 架构级约束：纯函数求值器——无状态、无 IO、不依赖 UI 与 ViewModel；
/// 每次按键都会被 LauncherViewModel.filterItems() 调用，必须保持微秒级开销。
///
/// 语法支持：
/// - 四则运算 `+ - * /`、幂 `^`（右结合）、阶乘 `!`（后缀）、一元正负号、括号
/// - 隐式乘法：`2pi`、`(1+2)(3+4)`、`2(3+4)`
/// - 百分比后缀：`50%` == 0.5（取模因此只能用 `mod(a,b)`，避免 `10%3` 的歧义）
/// - 常量：`pi/π`、`e`、`tau`、`phi`；函数与常量名大小写不敏感
/// - 函数：sin cos tan asin acos atan sinh cosh tanh sqrt cbrt ln log log2 exp
///         abs round floor ceil min max pow mod（min/max 变长；函数后括号可省略：`sqrt9` == `sqrt(9)`）
/// - 全角/数学符号归一化：＝ ＋ － × ÷ （ ） ， ％ ． ０-９ π √ ² ³
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
            case "。": break // 中文句末标点，静默吞掉
            default: out.append(ch)
            }
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
    ]

    private static let functions: [String: (arity: ClosedRange<Int>, apply: ([Double]) -> Double)] = [
        "sin": (1...1, { sin($0[0]) }),
        "cos": (1...1, { cos($0[0]) }),
        "tan": (1...1, { tan($0[0]) }),
        "asin": (1...1, { asin($0[0]) }),
        "acos": (1...1, { acos($0[0]) }),
        "atan": (1...1, { atan($0[0]) }),
        "sinh": (1...1, { sinh($0[0]) }),
        "cosh": (1...1, { cosh($0[0]) }),
        "tanh": (1...1, { tanh($0[0]) }),
        "sqrt": (1...1, { sqrt($0[0]) }),
        "cbrt": (1...1, { cbrt($0[0]) }),
        "ln": (1...1, { log($0[0]) }),
        "log": (1...1, { log10($0[0]) }), // 计算器惯例：log 为常用对数，自然对数用 ln
        "log2": (1...1, { log2($0[0]) }),
        "exp": (1...1, { exp($0[0]) }),
        "abs": (1...1, { abs($0[0]) }),
        "round": (1...1, { $0[0].rounded() }),
        "floor": (1...1, { floor($0[0]) }),
        "ceil": (1...1, { ceil($0[0]) }),
        "min": (2...Int.max, { $0.min() ?? .nan }),
        "max": (2...Int.max, { $0.max() ?? .nan }),
        "pow": (2...2, { pow($0[0], $0[1]) }),
        "mod": (2...2, { $0[0].truncatingRemainder(dividingBy: $0[1]) }),
    ]
}

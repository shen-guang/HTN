//
//  JTokenizer.swift
//  HTN
//
//  Created by DaiMing on 2018/4/27.
//

import Foundation

public struct JToken {
    public var type = JTokenType.none
    public var value = ""
    public var binop:Int = 0
    
    public var beforeExpr = false
    public var startsExpr = false
    public var isLoop = false
    public var isAssign = false
    public var prefix = false
    public var postfix = false
    public var rightAssociative = false
    
    public var isKeyword = false // 是否是关键字
}

public class JTokenizer {
    private var _input: String
    private var _index: String.Index
    
    public init(_ input: String) {
        _input = input.filterAnnotationBlock()
        _index = _input.startIndex
    }
    
    public func tokenizer() -> [JToken] {
        var tokens = [JToken]()
        // $  _  _= ${ 符号不放到里面
        // TODO: 找到合理了的处理 $， _， _=，和 ${ 的方法，其中 $ 和 _ 是可以放到变量开头的。
        let symbols = ["[", "]", "{", "{|", "}", "|}", "|", "(", ")", ",", ":", "::", ".", "?", "?.", "=>", "...", "=", "++", "--", ">", "`", "@", "#", "=", "+", "!", "~", "|>", "??", "||", "&&", "&", "==", "!=", "^", "<", "<<", ">>", "-", "%", "*", "/", "**"]
        let eofs = [" ", "\n", ";"]
        
        while let aChar = currentChar {
            
            let s = aChar.description
            
            // 处理 " 和 ' 符号，需要处理转义和另一个 " 和 ' 符号作为结束
            if s == "\"" || s == "'" {
                let closer = s
                var cSb = ""
                var escaped = false
                while currentChar != nil {
                    // token 里不用记录 " 或者 '
                    advanceIndex()
                    if escaped {
                        escaped = false
                    } else if currentChar?.description == "\\" {
                        escaped = true
                    } else if currentChar?.description == closer {
                        advanceIndex()
                        break
                    }
                    if let currentStr = currentChar?.description {
                        cSb.append(currentStr)
                    }
                }
                var tk = JToken()
                tk.type = .string
                tk.startsExpr = true
                tk.value = cSb
                tokens.append(tk)
                continue
            }
            
            // 处理 / 符号，这个是正则的处理，比如 if (/[0-9\.]/.test(currentChar)) {
            if s == "/" {
                var cSb = ""
                var escaped = false
                var tk = JToken()
                tk.type = .regular
                
                while let cChar = currentChar {
                    let str = cChar.description
                    cSb.append(str)
                    advanceIndex()
                    if escaped {
                        escaped = false
                    } else if str == "\\" {
                        escaped = true
                    } else if str == "]" {
                        if currentChar?.description == s {
                            cSb.append(s)
                            advanceIndex()
                            break
                        }
                    }
                    // 下个不是 [ 及不满足正则表达式，直接把 / 作为 token
                    if currentChar?.description != "[" && !escaped && str == "/" {
                        tk.type = .slash
                        break
                    }
                } // end while
                tk.value = cSb
                tokens.append(tk)
                continue
            } // end if
            
            
            // 处理 " ", "\n", ";" 等间隔符号
            if eofs.contains(s) {
                if s == "\n" || s == ";" {
                    while let cChar = currentChar {
                        let str = cChar.description
                        if str == "\n" || str == ";" {
                            advanceIndex()
                            continue
                        } else {
                            break
                        }
                    }
                    var tk = JToken()
                    tk.type = .eof
                    tokens.append(tk)
                } else {
                    // 空格
                    advanceIndex()
                }
                continue
            }
            // 使用 CharacterSet.newlines 的方式再处理下
            if CharacterSet.newlines.contains((currentChar?.unicodeScalars.first!)!) {
                while let character = currentChar, CharacterSet.newlines.contains(character.unicodeScalars.first!) {
                    advanceIndex()
                }
                var tk = JToken()
                tk.type = .eof
                tokens.append(tk)
                continue
            }
            
            if symbols.contains(s) {
                // 处理保留符号
                var cSb = ""
                while let cChar = currentChar {
                    let sb = cChar.description
                    if eofs.contains(sb) {
                        break //空字符和结束符时跳出
                    }
                    let checkForwardStr = cSb + sb
                    if symbols.contains(checkForwardStr) {
                        cSb = checkForwardStr
                    } else {
                        break //检查加上这个符号后是否满足组合保留符号
                    }
                    advanceIndex()
                    continue
                }
                if cSb == "" {
                    cSb = s
                }
                tokens.append(tokenFrom(cSb))
                continue
            } else if (s.isInt()) {
                // 处理数字
                // 在 else 条件里处理数字 0.1 这样的，当第一个是数字时，连续开始处理数字，有 . 符号也不 break，除非是碰到非数字或者其它符号
                var numStr = ""
                while let cChar = currentChar {
                    let str = cChar.description
                    if str.isInt() || str == "." {
                        numStr.append(str)
                    } else {
                        break
                    }
                    advanceIndex()
                }
                var tk = JToken()
                // 判断数字类型
                if numStr.isInt() {
                    tk.type = .int
                    tk.startsExpr = true
                }
                if numStr.isFloat() {
                    tk.type = .float
                    tk.startsExpr = true
                }
                tk.value = numStr
                tokens.append(tk)
                continue
            } else {
                // 处理关键字和其它定义字符集
                var word = ""
                // 处理 ${ 和 _= 组成符号的情况
                if currentChar?.description == "$" && self.peek == "{" {
                    word = "${"
                    advanceIndex()
                    advanceIndex()
                } else {
                    while let sChar = currentChar {
                        let str = sChar.description
                        
                        if symbols.contains(str) || eofs.contains(str) {
                            break
                        }
                        word.append(str)
                        advanceIndex()
                        continue
                    }
                }
                
                //开始把连续字符进行 token 存储
                if word.count > 0 {
                    // 这里返回的 token 类型如果是 none 表示的就是非关键字的变量，函数名和方法什么的
                    tokens.append(tokenFrom(word))
                }
                continue
            } // end if else
        } // end while
        
        return tokens
    }
    
    private func tokenFrom(_ input:String) -> JToken {
        var tk = JToken()
        switch input {
        case "[":
            tk.type = .bracketL
            tk.beforeExpr = true
            tk.startsExpr = true
        case "]":
            tk.type = .bracketR
        case "{":
            tk.type = .braceL
            tk.beforeExpr = true
            tk.startsExpr = true
        case "{|":
            tk.type = .braceBarL
            tk.beforeExpr = true
            tk.startsExpr = true
        case "}":
            tk.type = .braceR
        case "|}":
            tk.type = .braceBarR
        case "(":
            tk.type = .parenL
            tk.beforeExpr = true
            tk.startsExpr = true
        case ")":
            tk.type = .parenR
        case ",":
            tk.type = .comma
            tk.beforeExpr = true
        case ";":
            tk.type = .semi
            tk.beforeExpr = true
        case ":":
            tk.type = .colon
            tk.beforeExpr = true
        case "::":
            tk.type = .doubleColon
            tk.beforeExpr = true
        case ".":
            tk.type = .dot
        case "?":
            tk.type = .question
            tk.beforeExpr = true
        case "?.":
            tk.type = .questiondot
        case "=>":
            tk.type = .arrow
            tk.beforeExpr = true
        case "...":
            tk.type = .ellipsis
            tk.beforeExpr = true
        case "`":
            tk.type = .backQuote
            tk.startsExpr = true
        case "${":
            tk.type = .dollarBraceL
            tk.beforeExpr = true
            tk.startsExpr = true
        case "@":
            tk.type = .at
        case "#":
            tk.type = .hash
        
        // 操作符
        case "=":
            tk.type = .eq
            tk.beforeExpr = true
            tk.isAssign = true
        case "_=":
            tk.type = .assign
            tk.beforeExpr = true
            tk.isAssign = true
        case "++", "--":
            tk.type = .incDec
            tk.prefix = true
            tk.postfix = true
            tk.startsExpr = true
        case "!":
            tk.type = .bang
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
        case "~":
            tk.type = .tilde
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
        
        // 有优先级的操作符
        case "|>":
            tk.type = .pipleline
            tk.binop = 0
        case "??":
            tk.type = .nullishCoalescing
            tk.binop = 1
        case "||":
            tk.type = .logicalOR
            tk.binop = 1
        case "&&":
            tk.type = .logicalAND
            tk.binop = 2
        case "|":
            tk.type = .bitwiseOR
            tk.binop = 3
        case "^":
            tk.type = .bitwiseXOR
            tk.binop = 4
        case "&":
            tk.type = .bitwiseAND
            tk.binop = 5
        case "==", "!=", "===":
            tk.type = .equality
            tk.binop = 6
        case "<", ">":
            tk.type = .relational
            tk.binop = 7
        case "<<", ">>":
            tk.type = .bitShift
            tk.binop = 8
        case "+", "-":
            tk.type = .plusMin
            tk.binop = 9
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
        case "%":
            tk.type = .modulo
            tk.binop = 10
        case "*":
            tk.type = .star
            tk.binop = 10
        case "/":
            tk.type = .slash
            tk.binop = 10
        case "**":
            tk.type = .exponent
            tk.binop = 11
            tk.beforeExpr = true
            tk.rightAssociative = true
        
        // 关键字
        case "template":
            tk.type = .template
            tk.isKeyword = true
        case "break":
            tk.type = .break
            tk.isKeyword = true
        case "case":
            tk.type = .case
            tk.beforeExpr = true
            tk.isKeyword = true
        case "catch":
            tk.type = .catch
            tk.isKeyword = true
        case "continue":
            tk.type = .continue
            tk.isKeyword = true
        case "debugger":
            tk.type = .debugger
            tk.isKeyword = true
        case "default":
            tk.type = .default
            tk.beforeExpr = true
            tk.isKeyword = true
        case "do":
            tk.type = .do
            tk.isLoop = true
            tk.beforeExpr = true
            tk.isKeyword = true
        case "else":
            tk.type = .else
            tk.beforeExpr = true
            tk.isKeyword = true
        case "finally":
            tk.type = .finally
            tk.isKeyword = true
        case "for":
            tk.type = .for
            tk.isLoop = true
            tk.isKeyword = true
        case "function":
            tk.type = .function
            tk.startsExpr = true
            tk.isKeyword = true
        case "if":
            tk.type = .if
            tk.isKeyword = true
        case "return":
            tk.type = .return
            tk.beforeExpr = true
            tk.isKeyword = true
        case "switch":
            tk.type = .switch
            tk.isKeyword = true
        case "throw":
            tk.type = .throw
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
            tk.isKeyword = true
        case "try":
            tk.type = .try
            tk.isKeyword = true
        case "var":
            tk.type = .var
            tk.isKeyword = true
        case "let":
            tk.type = .let
            tk.isKeyword = true
        case "const":
            tk.type = .const
            tk.isKeyword = true
        case "while":
            tk.type = .while
            tk.isLoop = true
            tk.isKeyword = true
        case "with":
            tk.type = .with
            tk.isKeyword = true
        case "new":
            tk.type = .new
            tk.beforeExpr = true
            tk.startsExpr = true
            tk.isKeyword = true
        case "this":
            tk.type = .this
            tk.startsExpr = true
            tk.isKeyword = true
        case "super":
            tk.type = .super
            tk.startsExpr = true
            tk.isKeyword = true
        case "class":
            tk.type = .class
            tk.isKeyword = true
        case "extends":
            tk.type = .extends
            tk.beforeExpr = true
            tk.isKeyword = true
        case "export":
            tk.type = .export
            tk.isKeyword = true
        case "import":
            tk.type = .import
            tk.startsExpr = true
            tk.isKeyword = true
        case "yield":
            tk.type = .yield
            tk.beforeExpr = true
            tk.startsExpr = true
            tk.isKeyword = true
        case "null":
            tk.type = .null
            tk.startsExpr = true
            tk.isKeyword = true
        case "true":
            tk.type = .true
            tk.startsExpr = true
            tk.isKeyword = true
        case "false":
            tk.type = .false
            tk.startsExpr = true
            tk.isKeyword = true
        case "in":
            tk.type = .in
            tk.beforeExpr = true
            tk.binop = 7
            tk.isKeyword = true
        case "instance":
            tk.type = .instanceof
            tk.beforeExpr = true
            tk.binop = 7
            tk.isKeyword = true
        case "typeof":
            tk.type = .typeof
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
            tk.isKeyword = true
        case "void":
            tk.type = .void
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
            tk.isKeyword = true
        case "delete":
            tk.type = .delete
            tk.beforeExpr = true
            tk.prefix = true
            tk.startsExpr = true
            tk.isKeyword = true
        default:
            tk.type = .name
            tk.startsExpr = true
        }
        tk.value = input
        return tk
    }
    
    // parser tool
    var currentChar: Character? {
        return _index < _input.endIndex ? _input[_index] : nil
    }
    func advanceIndex() {
        if _index < _input.endIndex {
            _input.formIndex(after: &_index)
        }
        
    }
    // 访问下当前字符的下一个字符，而不更新当前字符位置
    var peek: Character? {
        if _index < _input.endIndex {
            let nextIndex =  _input.index(after: _index)
            return nextIndex < _input.endIndex ? _input[nextIndex] : nil
        } else {
            return nil
        }
        
    }
}

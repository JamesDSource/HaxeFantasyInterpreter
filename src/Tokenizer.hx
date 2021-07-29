import Data;
using hx.strings.Strings;

enum TokenType {
    Identifier(name: String);
    DataType(type: Data.DataType);

    Real(number: Float);
    Text(string: String);
    BoolConst(bool: Bool);

    Assign;
    Pow;
    Add;
    Sub;
    Mult;
    Div;
    Mod;
    Equals;
    Greater;
    Lesser;
    GreaterEquals;
    LesserEquals;
    And;
    Or;

    OpenParen;
    CloseParen;
    OpenCurly;
    CloseCurly;
    OpenBracket;
    CloseBracket;
    Comma;

    If;
    Elif;
    Else;

    NewLine;
}

typedef Token = {
    type: TokenType,
    startPos: Int,
    ?endPos: Null<Int>
}

class Tokenizer {
    public static final DIGITS: String = "1234567890";
    public static final LETTERS: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_";
    public static final LETTERS_DIGITS: String = DIGITS + LETTERS;

    public static final KEYWORDS: Array<{identifier: String, tType: TokenType}> = [
        {
            identifier: "true",
            tType: BoolConst(true)
        },
        {
            identifier: "false",
            tType: BoolConst(false)
        },
        {
            identifier: "and",
            tType: And
        },
        {
            identifier: "or",
            tType: Or  
        },
        {
            identifier: "if",
            tType: If
        },
        {
            identifier: "elif",
            tType: Elif
        },
        {
            identifier: "else",
            tType: Else
        }
    ];

    public static inline function getTokens(code: String): Array<Token> {
        var tokens: Array<Token> = [];
        
        var idleUntil: Int = 0;
        for(i in 0...code.length) {
            var isLast: Bool = i == code.length - 1;
            if(i < idleUntil)
                continue;

            var char = code.charAt(i);
            if(char == " ")
                continue;

            // Number token
            if(DIGITS.contains(char) || (char == "." && !isLast && DIGITS.contains(code.charAt(i + 1)))) {                
                var numb = char;

                var periods: Int = char == "." ? 1 : 0;
                // Start looping to find the rest of the number
                for(j in (i + 1)...code.length) {
                    var char = code.charAt(j);

                    // Checking if the char is not a number
                    if(!DIGITS.contains(char) && char != ".") {
                        idleUntil = j;
                        break;
                    }

                    // Checking if there is more than one period
                    if(char == ".") {
                        periods++;

                        if(periods > 1) {
                            idleUntil = j;
                            break;
                        }
                    }

                    numb += char;
                    if(j == code.length - 1)
                        idleUntil = j + 1;
                }
                
                // Parsing into a token
                var real: Null<Float> = numb.toFloat();
                if(real == null)
                    throw "Number is unparseable";

                tokens.push({type: Real(real), startPos: i, endPos: idleUntil});
                continue;
            }

            // Identifier token
            if(LETTERS.contains(char)) {
                var word = char;

                // Getting the word
                for(j in (i + 1)...code.length) {
                    var char = code.charAt(j);

                    if(LETTERS_DIGITS.contains(char))
                        word += char;
                    else {
                        idleUntil = j;
                        break; 
                    }

                    if(j == code.length - 1)
                        idleUntil = j + 1;
                }

                // Checking if the word is a data type
                var dataTypeFound: Bool = false;
                for(dataType in DataTypes.TYPES_ARRAY) {
                    if(dataType.identifier == word) {
                        tokens.push({type: DataType(dataType), startPos: i, endPos: idleUntil});
                        dataTypeFound = true;
                        break;
                    }
                }


                // Checking if the word is a keyword, if not, it's an identifier
                if(!dataTypeFound) {
                    var keywordFound: Bool = false;
                    for(keyword in KEYWORDS) {
                        if(keyword.identifier == word) {
                            tokens.push({type: keyword.tType, startPos: i, endPos: idleUntil});
                            keywordFound = true;
                            break;
                        }
                    }

                    if(!keywordFound)
                        tokens.push({type: Identifier(word), startPos: i, endPos: idleUntil});
                }
            }

            switch(char) {
                case "#":
                    for(j in (i + 1)...code.length) {
                        if(code.charAt(j) == "\n" || j == code.length - 1) {
                            idleUntil = j + 1;
                            break;
                        }
                    }
                case "\'", "\"":
                    var str: String = "";
                    for(j in (i + 1)...code.length) {
                        var char = code.charAt(j);
                        if(char == "\"" || char == "\'") {
                            idleUntil = j + 1;
                            break;
                        }

                        str += char;
                        if(j == code.length - 1)
                            throw "\" or \' Expected";
                    }
                    tokens.push({type: Text(str), startPos: i, endPos: idleUntil - 1});
                case "=":
                    if(!isLast && code.charAt(i + 1) == "=") {
                        tokens.push({type: Equals, startPos: i, endPos: i + 1});
                        idleUntil = i + 2;
                    }
                    else
                        tokens.push({type: Assign, startPos: i});
                case "^":
                    tokens.push({type:Pow, startPos: i});
                case "+":
                    tokens.push({type: Add, startPos: i});
                case "-":
                    tokens.push({type: Sub, startPos: i});
                case "*":
                    tokens.push({type: Mult, startPos: i});
                case "/":
                    tokens.push({type: Div, startPos: i});
                case "%":
                    tokens.push({type: Mod, startPos: i});
                case ">":
                    if(!isLast && code.charAt(i + 1) == "=") {
                        tokens.push({type: GreaterEquals, startPos: i, endPos: i + 1});
                        idleUntil = i + 2;
                    }
                    else
                        tokens.push({type: Greater, startPos: i});
                case "<":
                    if(!isLast && code.charAt(i + 1) == "=") {
                        tokens.push({type: LesserEquals, startPos: i, endPos: i + 1});
                        idleUntil = i + 2;
                    }
                    else
                        tokens.push({type: Lesser, startPos: i});
                case "&":
                    if(!isLast && code.charAt(i + 1) == "&") {
                        tokens.push({type: And, startPos: i, endPos: i + 1});
                        idleUntil = i + 2;
                    }
                case "|":
                    if(!isLast && code.charAt(i + 1) == "|") {
                        tokens.push({type: Or, startPos: i, endPos: i + 1}); 
                        idleUntil = i + 2;
                    }
                case "(":
                    tokens.push({type: OpenParen, startPos: i});
                case ")":
                    tokens.push({type: CloseParen, startPos: i});
                case "{":
                    tokens.push({type: OpenCurly, startPos: i});
                case "}":
                    tokens.push({type: CloseCurly, startPos: i});
                case "[":
                    tokens.push({type: OpenBracket, startPos: i});
                case "]":
                    tokens.push({type: CloseBracket, startPos: i});
                case ",":
                    tokens.push({type: Comma, startPos: i});
                case ";":
                    tokens.push({type: NewLine, startPos: i});
            }
        }

        return tokens;
    }

    public static inline function toString(tokenType: TokenType): String {
        return switch(tokenType) {
            case DataType(type):
                'TYPE:${type.identifier}';
            case Identifier(name):
                'IDENTIFIER:$name';
            case Real(number):
                'REAL:$number';
            case Text(string):
                'TEXT:$string';
            case BoolConst(bool):
                'BOOL:$bool';
            case Assign:
                "=";
            case Pow:
                "^";
            case Add:
                "+";
            case Sub:
                "-";
            case Mult:
                "*";
            case Div:
                "/";
            case Mod:
                "%";
            case Equals:
                "==";
            case Greater:
                ">";
            case GreaterEquals:
                ">=";
            case Lesser:
                "<";
            case LesserEquals:
                "<=";
            case And:
                "AND";
            case Or:
                "OR";
            case OpenParen:
                "(";
            case CloseParen:
                ")";
            case OpenBracket:
                "[";
            case CloseBracket:
                "]";
            case Comma:
                ",";
            case If:
                "IF";
            case Elif:
                "ELIF";
            case Else:
                "ELSE";
            case NewLine:
                ";";
            default:
                "Default Token";
        }
    }
}
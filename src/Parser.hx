import AstNode;

typedef Error = {
    message: String,
    line: Int
}

class Parser {
    public var tokens: Array<Tokenizer.Token>;
    private var tokenIndex: Int;
    private var currentToken: Tokenizer.Token;
    private var peekToken: Tokenizer.Token;

    private var errors: Array<Error>;

    public function new(tokens: Array<Tokenizer.Token>) {
        this.tokens = tokens;
    }

    private function nextToken(i: Int = 1): Bool {
        tokenIndex += i;
        currentToken = tokenIndex < tokens.length ? tokens[tokenIndex] : null;
        return currentToken != null;
    }

    private function peek(i: Int = 1): Tokenizer.Token {
        var peekIndex: Int = tokenIndex + i;
        return peekToken = peekIndex < tokens.length ? tokens[peekIndex] : null;
    }

    public function parse(): AstNode {
        errors = [];
        tokenIndex = -1;
        currentToken = null;
        peekToken = null;
        nextToken();
        return statement();
    }

    private function factor(): AstNode {
        var token = currentToken;
        if(token == null)
            return null;

        switch(token.type) {
            case DataType(type):
                var dependencies: Array<AstNode> = [];
                if(nextToken() && currentToken.type == Lesser) {   
                    nextToken();
                    var dependentType = factor();
                    dependencies.push(dependentType);
                    if(currentToken != null && currentToken.type == Greater)
                        nextToken();
                    else
                        throw "> expected";
                }                
                return new AstDataTypeNode(type, dependencies);
            case Identifier(name):
                nextToken();
                return new AstVarAccessNode(name);
            case Real(number):
                nextToken();
                return new AstNumbNode(number);
            case Text(string):
                nextToken();
                return new AstStrNode(string);
            case BoolConst(bool):
                nextToken();
                return new AstBoolNode(bool);
            case Add, Sub:
                nextToken();
                var fact = factor();
                return new AstUnaryOpNode(token.type, fact);
            case OpenParen:
                nextToken();
                var expr = expression();
                if(currentToken != null && currentToken.type == CloseParen) {
                    nextToken();
                    return expr;
                }
                return null;
            case If:
                return ifExpr();
            default:
                return null;
        }
    }

    private function accesssor(): AstNode {
        var left: AstNode = factor();
        
        var gotAccessor: Bool = false;
        while(currentToken != null && currentToken.type == OpenBracket) {
            nextToken();
            var index = expression();
            if(currentToken == null || currentToken.type != CloseBracket)
                throw "] Expected";
            nextToken();
            left = new AstArrayAccessNode(left, index);
            gotAccessor = true;
        }

        if(gotAccessor && currentToken != null && currentToken.type == Assign) {
            var accessNode: AstArrayAccessNode = cast left;
            nextToken();
            accessNode.assign = expression();
        }
        
        return left;
    }

    private function power(): AstNode {
        return binOperation(accesssor, [Pow]);
    }

    private function term(): AstNode {
        return binOperation(power, [Mult, Div, Mod]);
    }

    private function arithmatic(): AstNode {
        return binOperation(term, [Add, Sub]);
    }

    private function compare(): AstNode {
        return binOperation(arithmatic, [Equals, Greater, Lesser, GreaterEquals, LesserEquals]);
    }

    private function expression(): AstNode {
        var token = currentToken;
        switch(token.type) {
            case DataType(type):
                var type = factor();
                switch(currentToken.type) {
                    case Identifier(name):    
                        var init: AstNode = null;
                        if(nextToken() && currentToken.type == Assign) {
                            nextToken();
                            init = expression();
                        }
                        return new AstAssignmentNode(name, type, init);
                    
                    default:
                }
            case Identifier(name):
                peek();
                switch(peekToken.type) {
                    case Assign:
                        nextToken(2);
                        var value = expression();
                        return new AstAssignmentNode(name, null, value);
                    default:
                }
            case OpenBracket:
                return listExpr();
            default:
        }

        return binOperation(compare, [And, Or]);
    }

    private function statement(): AstNode {
        var statements: Array<AstNode> = [expression()];
        var afterCurly: Bool = false;
        while(  
                currentToken != null && 
                (
                    currentToken.type == NewLine || 
                    (afterCurly = peek(-1) != null && peekToken.type == CloseCurly)
                )
            ) 
        {
            if(afterCurly || nextToken()) {
                afterCurly = false;
                if(currentToken.type == CloseCurly)
                    break;

                statements.push(expression());
            }
        }

        return new AstListNode(statements);
    }

    private function binOperation(func: () -> AstNode, operators: Array<Tokenizer.TokenType>): AstNode {
        var left = func();

        while(currentToken != null && operators.contains(currentToken.type)) {
            var opToken = currentToken.type;
            nextToken();
            var right = func();
            left = new AstBinOpNode(left, right, opToken);
        }

        return left;
    }

    private function listExpr(): AstNode {
        if(nextToken() && currentToken.type == CloseBracket) {
            nextToken();
            return new AstListNode([]);
        }
        var elements: Array<AstNode> = [expression()];

        while(currentToken.type == Comma) {
            if(nextToken())
                elements.push(expression());
            else
                throw "] Expected";
        }

        if(currentToken == null || currentToken.type != CloseBracket)
            throw ", or ] Expected";

        nextToken();
        return new AstListNode(elements);
    }

    private function ifExpr(): AstNode {
        var cases: Array<IfCase> = [];
        
        nextToken();
        var condition = expression();
        cases.push({condition: condition, result: curlyStatement()});

        while(currentToken != null && currentToken.type == Elif) {
            nextToken();
            var condition = expression();
            cases.push({condition: condition, result: curlyStatement()});
        }

        var elseCase: AstNode = null;
        if(currentToken != null && currentToken.type == Else) {
            nextToken();
            elseCase = curlyStatement();
        }

        return new AstIfChainNode(cases, elseCase);
    }

    private function curlyStatement(): AstNode {
        if(currentToken == null)
            throw "{ or Expression Expected";
        
        var caseResult: AstNode;
        if(currentToken.type == OpenCurly) {
            nextToken();
            caseResult = statement();
            if(currentToken == null || currentToken.type != CloseCurly)
                throw "} Expected";
            nextToken();
        }
        else {
            caseResult = expression();
            if(currentToken != null && currentToken.type == NewLine)
                nextToken();
        }

        return caseResult;
    }
}
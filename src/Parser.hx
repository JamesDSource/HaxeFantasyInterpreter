import AstNode;

typedef Error = {
    message: String,
    line: Int
}

class Parser {
    public var tokens: Array<Tokenizer.Token>;
    private var text: String;
    private var tokenIndex: Int;
    private var currentToken: Tokenizer.Token;
    private var peekToken: Tokenizer.Token;

    private var errors: Array<Error>;

    public function new(?tokens: Array<Tokenizer.Token>, text: String) {
        this.text = text;
        this.tokens = tokens != null ? tokens : Tokenizer.getTokens(text);
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
                    if(dependentType.isError)
                        return dependentType;
                    dependencies.push(dependentType);
                    if(currentToken != null && currentToken.type == Greater)
                        nextToken();
                    else
                        return AstSyntaxErrorNode.expected(">", text, dependentType.positionEnd);
                }                
                return new AstDataTypeNode(type, dependencies, token.startPos, token.endPos);
            case Identifier(name):
                nextToken();
                return new AstVarAccessNode(name, token.startPos, token.endPos);
            case Real(number):
                nextToken();
                return new AstNumbNode(number, token.startPos, token.endPos);
            case Text(string):
                nextToken();
                return new AstStrNode(string, token.startPos, token.endPos);
            case BoolConst(bool):
                nextToken();
                return new AstBoolNode(bool, token.startPos, token.endPos);
            case Add, Sub:
                nextToken();
                var fact = factor();
                if(fact.isError)
                    return fact;
                return new AstUnaryOpNode(token.type, fact, token.startPos, fact.positionEnd);
            case OpenParen:
                nextToken();
                var expr = expression();
                if(expr.isError)
                    return expr;
                if(currentToken != null && currentToken.type == CloseParen) {
                    nextToken();
                    return expr;
                }
                return AstSyntaxErrorNode.expected(")", text, peek(-1).endPos);
            case If:
                return ifExpr();
            default:
                return new AstSyntaxErrorNode("Invalid Token", text, token.startPos);
        }
    }

    private function accesssor(): AstNode {
        var left: AstNode = factor();
        if(left.isError)
            return left;
        
        var gotAccessor: Bool = false;
        while(currentToken != null && currentToken.type == OpenBracket) {
            nextToken();
            var index = expression();
            if(index.isError)
                return index;

            if(currentToken == null || currentToken.type != CloseBracket)
                return AstSyntaxErrorNode.expected("]", text, index.positionEnd);
            left = new AstArrayAccessNode(left, index, left.positionStart, currentToken.endPos);
            nextToken();
            gotAccessor = true;
        }

        if(gotAccessor && currentToken != null && currentToken.type == Assign) {
            var accessNode: AstArrayAccessNode = cast left;
            nextToken();
            accessNode.assign = expression();
            if(accessNode.assign.isError)
                return accessNode.assign;
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
                if(type.isError)
                    return type;
                switch(currentToken.type) {
                    case Identifier(name):    
                        var positionEnd: Int = currentToken.endPos;
                        var init: AstNode = null;
                        if(nextToken() && currentToken.type == Assign) {
                            nextToken();
                            init = expression();
                            if(init.isError)
                                return init;
                            positionEnd = init.positionEnd;
                        }
                        return new AstAssignmentNode(name, type, init, token.startPos, positionEnd);
                    
                    default:
                }
            case Identifier(name):
                peek();
                switch(peekToken.type) {
                    case Assign:
                        nextToken(2);
                        var value = expression();
                        if(value.isError)
                            return value;
                        return new AstAssignmentNode(name, null, value, token.startPos, value.positionEnd);
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
        if(statements[0].isError)
            return statements[0];
        var afterCurly: Bool = false;

        var startPosition: Int = statements[0].positionStart;
        var endPosition: Int = 0;

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

                var statement = expression();
                if(statement.isError)
                    return statement;
                statements.push(statement);
                endPosition = statement.positionEnd;
            }
        }

        if(currentToken != null)
            return AstSyntaxErrorNode.expected(";", text, endPosition);

        return new AstListNode(statements, startPosition, endPosition);
    }

    // Helper function for binary operation layers
    private function binOperation(func: () -> AstNode, operators: Array<Tokenizer.TokenType>): AstNode {
        var left = func();
        if(left.isError)
            return left;

        while(currentToken != null && operators.contains(currentToken.type)) {
            var opToken = currentToken.type;
            nextToken();
            var right = func();
            if(right.isError)
                return right;
            left = new AstBinOpNode(left, right, opToken, left.positionStart, right.positionEnd);
        }

        return left;
    }

    private function listExpr(): AstNode {
        if(nextToken() && currentToken.type == CloseBracket) {
            var pos = currentToken.startPos;
            nextToken();
            return new AstListNode([], pos);
        }

        var elements: Array<AstNode> = [expression()];
        if(elements[0].isError)
            return elements[0];
        var startPosition = elements[0].positionStart;
        var endPosition: Int = elements[0].positionEnd;
        while(currentToken.type == Comma) {
            if(nextToken()) {
                var element = expression();
                if(element.isError)
                    return element;
                elements.push(element);
                endPosition = element.positionEnd;
            }
            else
                return AstSyntaxErrorNode.expected("]", text, peek(-1).endPos);
        }

        if(currentToken == null || currentToken.type != CloseBracket)
            return AstSyntaxErrorNode.expected([",", "]"], text, peek(-1).endPos);

        nextToken();
        return new AstListNode(elements, startPosition, endPosition);
    }

    private function ifExpr(): AstNode {
        var cases: Array<IfCase> = [];
        var startPosition: Int = currentToken.startPos;
        var endPosition: Int = currentToken.endPos;

        nextToken();
        var condition = expression();
        if(condition.isError)
            return condition;
        
        var cs = curlyStatement();
        if(cs.isError)
            return cs;
        cases.push({condition: condition, result: cs});
        
        if( currentToken != null && 
            currentToken.type == NewLine && 
            peek(1) != null && 
            (
                peekToken.type == Elif || 
                peekToken.type == Else
            )
        ) nextToken();

        while(currentToken != null && currentToken.type == Elif) {
            nextToken();
            var condition = expression();
            if(condition.isError)
                return condition;
            
            var cs = curlyStatement();
            if(cs.isError)
                return cs;
            cases.push({condition: condition, result: cs});
            endPosition = cs.positionEnd;

            if( currentToken != null && 
                currentToken.type == NewLine && 
                peek(1) != null && 
                (
                    peekToken.type == Elif || 
                    peekToken.type == Else
                )
            ) nextToken();
        }

        var elseCase: AstNode = null;
        if(currentToken != null && currentToken.type == Else) {
            nextToken();
            elseCase = curlyStatement();
        }

        return new AstIfChainNode(cases, elseCase, startPosition, endPosition);
    }

    private function curlyStatement(): AstNode {
        if(currentToken == null)
            return AstSyntaxErrorNode.expected(["{", "Expression"], text, peek(-1).endPos);
        
        var caseResult: AstNode;
        if(currentToken.type == OpenCurly) {
            if(nextToken() && currentToken.type == CloseCurly) {
                var pos = currentToken.startPos;
                nextToken();
                return new AstListNode([], pos);
            }

            caseResult = statement();
            if(caseResult.isError)
                return caseResult;
            if(currentToken == null || currentToken.type != CloseCurly)
                return AstSyntaxErrorNode.expected("}", text, peek(-1).endPos);
            nextToken();
        }
        else
            caseResult = expression();

        return caseResult;
    }
}
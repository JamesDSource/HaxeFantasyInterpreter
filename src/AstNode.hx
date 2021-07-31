import Data;

class AstNode {
    public var isError: Bool = false;
    public var positionStart: Int;
    public var positionEnd: Int;

    public function new(positionStart: Int, ?positionEnd: Int) {
        this.positionStart = positionStart;
        this.positionEnd = positionEnd != null ? positionEnd : positionStart;
    }

    public function getResultType(context: Context): DataTypeInstance {
        return DataTypeInstance.fromData(getResult(context));
    }
    
    public function getResult(context: Context): Data {
        return Nothing;
    }

    public function toString(): String {
        return "Default Node";
    }
}


class AstSyntaxErrorNode extends AstNode {
    public var message: String;
    public var text: String;

    private var lineStart: Int;
    private var lineEnd: Int;

    public static function expected(?expected: Null<String>, ?expectedAll: Array<String>, text: String, positionStart: Int, ?positionEnd: Int): AstSyntaxErrorNode {
        var msg: String = "";
        if(expectedAll != null) {
            switch(expectedAll.length) {
                case 0:
                    // Do nothing
                case 1:
                    msg = expectedAll[0] + " ";
                case 2:
                    msg = '${expectedAll[0]} or ${expectedAll[1]} ';
                case l:
                    for(i in 0...l) {
                        if(i == l - 1)
                            msg += " or ";
                        msg += expectedAll[i];
                        if(i < l - 1)
                            msg += ", ";
                    }
                    msg += " ";
            }
        }
        else if(expected != null)
            msg = expected + " ";

        return new AstSyntaxErrorNode(msg + "Expected", text, positionStart, positionEnd);
    }

    public function new(message: String, text: String, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.message = message;
        this.text = text;
        isError = true;

        var lines: Int = 1;
        for(i in 0...this.positionEnd + 1) {
            if(text.charAt(i) == "\n")
                lines++;

            if(i == this.positionStart)
                lineStart = lines;
        }
        lineEnd = lines;
    }

    public override function toString():String {
        return "ERROR: " + message + (lineStart == lineEnd ? ' on line $lineStart' : ' from line $lineStart to $lineEnd');
    }
}

class AstDataTypeNode extends AstNode {
    public var type: DataType;
    public var dependencies: Array<AstNode> = [];

    public function new(type: DataType, ?dependencies: Array<AstNode>, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.type = type;
        if(dependencies != null)
            this.dependencies = dependencies;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        var instDependencies: Array<DataTypeInstance> = [];
        for(dependency in dependencies) {
            switch(dependency.getResult(context)) {
                case DType(dataType):
                    instDependencies.push(dataType);
                case exception:
                    throw 'Cannot use $exception as a dependency';
            }
        }

        return new DataTypeInstance(type, instDependencies);
    }

    public override function getResult(context:Context):Data {
        return DType(getResultType(context));
    }

    public override function toString():String {
        var depString: String = ", DEPENDENCIES:";
        for(i in 0...dependencies.length)
            depString += dependencies[i].toString() + (i < dependencies.length - 1 ? ", " : "");
        return '(TYPE:${type.identifier}${dependencies.length > 0 ? depString : ""})';
    }
}

class AstNumbNode extends AstNode {
    public var value: Float;

    public function new(value: Float, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.value = value;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        return new DataTypeInstance(DataTypes.TYPES.REAL);
    }

    public override function getResult(context: Context):Data {
        return Real(value);
    }

    public override function toString(): String {
        return 'NUMB:$value';
    }
}

class AstStrNode extends AstNode {
    public var value: String;

    public function new(value: String, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.value = value;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        return new DataTypeInstance(DataTypes.TYPES.STRING);
    }

    public override function getResult(context: Context):Data {
        return Str(value);
    }

    public override function toString(): String {
        return 'STRING:$value';
    }
}

class AstBoolNode extends AstNode {
    public var value: Bool;

    public function new(value: Bool, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.value = value;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        return new DataTypeInstance(DataTypes.TYPES.BOOL);
    }

    public override function getResult(context: Context):Data {
        return Boolean(value);
    }

    public override function toString(): String {
        return 'BOOL:$value';
    }
}

enum OpPair {
    Invalid;
    RealReal(v1: Float, v2: Float);
    StrStr(v1: String, v2: String);
    StrReal(v1: String, v2: Float);
    RealStr(v1: Float, v2: String);
    BoolBool(v1: Bool, v2: Bool);
}

class AstBinOpNode extends AstNode {
    public var left: AstNode;
    public var right: AstNode;
    public var operatorToken: Tokenizer.TokenType;
    
    public function new(left: AstNode, right: AstNode, operatorToken: Tokenizer.TokenType, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.left = left;
        this.right = right;
        this.operatorToken = operatorToken;
    }

    public override function getResult(context: Context): Data {
        var pair = getPair(left.getResult(context), right.getResult(context));

        switch(operatorToken) {
            case Pow:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Real(Math.pow(v1, v2));
                    default:
                }
            case Add:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Real(v1 + v2);
                    case StrStr(v1, v2):
                        return Str(v1 + v2);
                    case RealStr(v1, v2):
                        return Str('$v1$v2');
                    case StrReal(v1, v2):
                        return Str('$v1$v2');
                    default: 
                } 
            case Sub:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Real(v1 - v2);
                    default: 
                }
            case Mult:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Real(v1*v2);
                    default: 
                }
            case Div:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Real(v1/v2);
                    default: 
                }
            case Mod:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Real(v1%v2);
                    default: 
                }
            case Equals:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Boolean(v1 == v2);
                    case StrStr(v1, v2):
                        return Boolean(v1 == v2);
                    case BoolBool(v1, v2):
                        return Boolean(v1 == v2);
                    default:
                }
            case Greater:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Boolean(v1 > v2);
                    case StrStr(v1, v2):
                        return Boolean(v1 > v2);
                    default:
                }
            case GreaterEquals:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Boolean(v1 >= v2);
                    case StrStr(v1, v2):
                        return Boolean(v1 >= v2);
                    default:
                }
            case Lesser:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Boolean(v1 < v2);
                    case StrStr(v1, v2):
                        return Boolean(v1 < v2);
                    default:
                }
            case LesserEquals:
                switch(pair) {
                    case RealReal(v1, v2):
                        return Boolean(v1 <= v2);
                    case StrStr(v1, v2):
                        return Boolean(v1 <= v2);
                    default:
                }
            case And:
                switch(pair) {
                    case BoolBool(v1, v2):
                        return Boolean(v1 && v2);
                    default:
                }
            case Or:
                switch(pair) {
                    case BoolBool(v1, v2):
                        return Boolean(v1 || v2);
                    default:
                }
            default:
        }   

        return Nothing;
    }

    private inline function getPair(data1: Data, data2: Data): OpPair {
        return switch(data1) {
            case Real(float1):
                switch(data2) {
                    case Real(float2):
                        RealReal(float1, float2);
                    case Str(string):
                        RealStr(float1, string);
                    default:
                        Invalid;
                }
            case Str(string1):
                switch(data2) {
                    case Str(string2):
                        StrStr(string1, string2);
                    case Real(float):
                        StrReal(string1, float);
                    default:
                        Invalid;
                }
            case Boolean(bool1):
                switch(data2) {
                    case Boolean(bool2):
                        BoolBool(bool1, bool2);
                    default:
                        Invalid;
                }
            default:
                Invalid;
        }
    }

    public override function toString(): String {
        return '(${left.toString()} ${Tokenizer.toString(operatorToken)} ${right.toString()})';
    }
}

class AstUnaryOpNode extends AstNode {
    public var opToken: Tokenizer.TokenType;
    public var node: AstNode;
    
    public function new(opToken: Tokenizer.TokenType, node: AstNode, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.opToken = opToken;
        this.node = node;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        return new DataTypeInstance(DataTypes.TYPES.REAL);
    }

    public override function getResult(context: Context):Data {
        var r = node.getResult(context);
        var number: Float;

        switch (r) {
            case Real(float):
                number = float;
            default:
                return Nothing;
        }
        
        switch(opToken) {
            case Add:
                return Real(number);
            case Sub:
                return Real(-number);
            default:
                return Nothing;
        }
    }

    public override function toString():String {
        return '(${Tokenizer.toString(opToken)}${node.toString()})';
    }
}

class AstVarAccessNode extends AstNode {
    public var variableName: String;

    public function new(variableName: String, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.variableName = variableName;
    }

    public override function getResult(context:Context):Data {
        var variable = context.getVariable(variableName);
        if(variable == null)
            throw "Trying to access variable that was never defined";
        return variable.value;
    }

    public override function toString():String {
        return 'VARIABLE:$variableName';
    }
}

class AstAssignmentNode extends AstNode {
    public var variableName: String;
    public var initType: AstNode;
    public var assignedTo: AstNode;

    public function new(variableName: String, ?initType: AstNode, ?assignedTo: AstNode, positionStart: Int, positionEnd: Int) {
        super(positionStart, positionEnd);
        this.variableName = variableName;
        this.initType = initType;
        this.assignedTo = assignedTo;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        if(initType != null)
            return initType.getResultType(context);

        var variable = context.getVariable(variableName);
        if(variable == null)
            return new DataTypeInstance(DataTypes.TYPES.DYNAMIC);
        return variable.typeInst;
    }

    public override function getResult(context: Context):Data {
        if(initType != null) {
            switch(initType.getResult(context)) {
                case DType(dataType):
                    var value = assignedTo == null ? null : assignedTo.getResult(context);
                    context.createVariable(variableName, dataType, value);
                    return value == null ? Nothing : value;
                default:
                    return Nothing;
            }
        }
        else {
            var variable = context.getVariable(variableName);
            if(variable == null || assignedTo == null)
                return Nothing;
            
            var value = assignedTo.getResult(context);
            context.setVariable(variable, value);
            return value;
        }

        return Nothing;
    }

    public override function toString():String {
        return '(ASSIGN:${initType != null ? '$initType' : ""} $variableName${assignedTo != null ? ' = ${assignedTo.toString()}' : ""})';
    }
}

class AstArrayAccessNode extends AstNode {
    public var accessed: AstNode;
    public var index: AstNode;
    public var assign: AstNode;
    
    public function new(accessed: AstNode, index: AstNode, ?assign: AstNode, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.accessed = accessed;
        this.index = index;
        this.assign = assign;
    }

    public override function getResultType(context:Context):DataTypeInstance {
        var t = accessed.getResultType(context);
        return t.type.typeDependencies > 0 ? accessed.getResultType(context).getDependency() : new DataTypeInstance(DataTypes.TYPES.DYNAMIC);
    }

    public override function getResult(context:Context):Data {
        var resultA: Data = accessed.getResult(context);
        var resultB: Data = index.getResult(context);

        switch(resultA) {
            case ArrayList(type, list):
                switch(resultB) {
                    case Real(float):
                        var i = Math.floor(float);
                        if(assign == null)
                            return list[i];
                        else {
                            if(!type.equals(assign.getResultType(context)))
                                throw "Trying to set array value to invalid type";
                            
                            return list[i] = assign.getResult(context);
                        }
                    default:
                }
            default:
                
        }
        throw "Invalid use of array access";
        return Nothing;
    }

    public override function toString():String {
        return '(${accessed.toString()}[${index.toString()}]${assign != null ? ' = ${assign.toString()}' : ""})';
    }
}

class AstListNode extends AstNode {
    public var elementNodes: Array<AstNode> = [];

    public function new(elementNodes: Array<AstNode>, positionStart: Int, ?positionEnd: Int) {
        super(positionStart, positionEnd);
        this.elementNodes = elementNodes;
    }

    // If all the elements are the same type, then the list will carry that type, otherwise it's dynamic
    public override function getResultType(context:Context):DataTypeInstance {
        var type: DataTypeInstance = null;
        if(elementNodes.length > 0) {
            type = elementNodes[0].getResultType(context);
            for(element in elementNodes) {
                if(!type.equals(element.getResultType(context))) {
                    type = null;
                    break;
                }
            }
        }
        if(type == null)
            type = new DataTypeInstance(DataTypes.TYPES.DYNAMIC);
        return new DataTypeInstance(DataTypes.TYPES.ARRAY_LIST, [type]);
    }

    public override function getResult(context:Context): Data {
        var type = getResultType(context).getDependency();
        var list: Array<Data> = [
            for(element in elementNodes)
                element.getResult(context)
        ];
        return ArrayList(type, list);
    }

    public override function toString():String {
        var str: String = "[";
        for(i in 0...elementNodes.length)
            str += elementNodes[i].toString() + (i < elementNodes.length - 1 ? ", " : "");

        return str + "]";
    }
}

typedef IfCase = {
    condition: AstNode,
    result: AstNode
}

class AstIfChainNode extends AstNode {
    public var cases: Array<IfCase>;
    public var elseCase: AstNode;

    public function new(cases: Array<IfCase>, ?elseCase: AstNode, positionStart: Int, positionEnd: Int) {
        super(positionStart, positionEnd);
        this.cases = cases.copy();
        this.elseCase = elseCase;
    }

    public override function getResultType(context:Context): DataTypeInstance {
        var type: DataTypeInstance = null;

        var allCases = cases.copy();
        if(elseCase != null)
            allCases.push({condition: null, result: elseCase});

        if(allCases.length > 0) {
            type = allCases[0].result.getResultType(context);
            for(ifCase in allCases) {
                if(!type.equals(ifCase.result.getResultType(context))) {
                    type = null;
                    break;
                }
            }
        }

        if(type == null)
            type = new DataTypeInstance(DataTypes.TYPES.DYNAMIC);
        return type;
    }

    public override function getResult(context:Context):Data {
        for(ifCase in cases) {
            switch(ifCase.condition.getResult(context)) {
                case Boolean(bool):
                    if(bool) {
                        context.addScope();
                        var result = ifCase.result.getResult(context);
                        context.pop();
                        return result;
                    }
                default:
                    throw "Bool Expected";
            };
        }

        if(elseCase != null) {
            context.addScope();
            var result = elseCase.getResult(context);
            context.pop();
            return result;
        }
        
        return Nothing;
    }

    public override function toString():String {
        var str: String = '';

        for(i in 0...cases.length) {
            str += i == 0 ? "IF: (" : "ELIF: (";
            str += cases[i].condition.toString() + "): " + cases[i].result.toString();
            if(i < cases.length - 1)
                str += ", ";
        }

        if(elseCase != null) 
            str += ', ELSE: (${elseCase.toString()})';

        return str;
    }
}
typedef Variable = {
    typeInst: DataTypeInstance,
    value: Data
}

typedef Func = {
    returnType: DataTypeInstance,
    parameters: Array<{name: String, type: DataTypeInstance, optional: Bool, ?defaultInit: Data}>,
    method: AstNode
}

class DataType {
    public var identifier(default, null): String;
    public var typeDependencies(default, null): Int;

    public var feilds: Map<String, Variable> = [];

    public function new(identifier: String, typeDependencies: Int = 0) {
        this.identifier = identifier;
        this.typeDependencies = typeDependencies;
    }
}

class DataTypeInstance {
    public var type(default, null): DataType;
    public var dependencies(default, null): Array<DataTypeInstance> = [];

    public static function fromData(data: Data): DataTypeInstance {
        switch(data) {
            case DType(dataType):
                return dataType;
            case Nothing:
                return null;
            case Real(float):
                return new DataTypeInstance(DataTypes.BASE_TYPES.REAL);
            case Str(string):
                return new DataTypeInstance(DataTypes.BASE_TYPES.STRING);
            case Boolean(bool):
                return new DataTypeInstance(DataTypes.BASE_TYPES.BOOL);
            case ArrayList(type, list):
                return new DataTypeInstance(DataTypes.BASE_TYPES.ARRAY_LIST, [type]);
            // TODO: Develop these because they are place holders to please the compiler
            case Instance(scope):
                return new DataTypeInstance(new DataType("Something"));
            case Function(func):
                return new DataTypeInstance(new DataType("Function"));
        }
    }

    public function new(type: DataType, ?dependencies: Array<DataTypeInstance>) {
        this.type = type;
        if(dependencies != null)
            this.dependencies = dependencies;

        if(type.typeDependencies != this.dependencies.length)
            throw "Incorrect number of dependencies";
    }

    public inline function getDependency(i: Int = 0): DataTypeInstance {
        if(dependencies.length < i + 1) 
            return null;
        
        return dependencies[i];
    }

    public function equals(d: DataTypeInstance): Bool {
        if(d == null || type != d.type || dependencies.length != d.dependencies.length)
            return false;

        for(i in 0...dependencies.length) {
            if(!dependencies[i].equals(d.dependencies[i]))
                return false;
        }

        return true;
    }
}

class DataTypes {
    public static final BASE_TYPES: {
        DYNAMIC: DataType,
        STRING: DataType,
        REAL: DataType,
        BOOL: DataType,
        ARRAY_LIST: DataType
    } = {
        DYNAMIC:    new DataType("Dynamic"),
        STRING:     new DataType("String"),
        REAL:       new DataType("Real"),
        BOOL:       new DataType("Bool"),
        ARRAY_LIST: new DataType("List", 1)
    }

    public static final BASE_TYPES_ARRAY: Array<DataType> = [
        BASE_TYPES.DYNAMIC,
        BASE_TYPES.STRING,
        BASE_TYPES.REAL,
        BASE_TYPES.BOOL,
        BASE_TYPES.ARRAY_LIST
    ];
}

enum Data {
    DType(dataType: DataTypeInstance);
    Nothing;
    Real(float: Null<Float>);
    Str(string: Null<String>);
    Boolean(bool: Null<Bool>);
    ArrayList(type: DataTypeInstance, list: Array<Data>);
    Instance(scope: Context.Scope);
    Function(func: Func);
}
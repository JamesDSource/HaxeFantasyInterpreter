typedef DataType = {
    identifier: String,
    typeDependencies: Int
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
                return new DataTypeInstance(DataTypes.TYPES.REAL);
            case Str(string):
                return new DataTypeInstance(DataTypes.TYPES.STRING);
            case Boolean(bool):
                return new DataTypeInstance(DataTypes.TYPES.BOOL);
            case ArrayList(type, list):
                return new DataTypeInstance(DataTypes.TYPES.ARRAY_LIST, [type]);
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
    public static final TYPES: {
        DYNAMIC: DataType,
        STRING: DataType,
        REAL: DataType,
        BOOL: DataType,
        ARRAY_LIST: DataType
    } = {
        DYNAMIC:    {identifier: "Dynamic", typeDependencies: 0},
        STRING:     {identifier: "String", typeDependencies: 0},
        REAL:       {identifier: "Real", typeDependencies: 0},
        BOOL:       {identifier: "Bool", typeDependencies: 0},
        ARRAY_LIST: {identifier: "List", typeDependencies: 1}
    }

    public static final TYPES_ARRAY: Array<DataType> = [
        TYPES.DYNAMIC,
        TYPES.STRING,
        TYPES.REAL,
        TYPES.BOOL,
        TYPES.ARRAY_LIST
    ];
}

enum Data {
    DType(dataType: DataTypeInstance);
    Nothing;
    Real(float: Null<Float>);
    Str(string: Null<String>);
    Boolean(bool: Null<Bool>);
    ArrayList(type: DataTypeInstance, list: Array<Data>);
}
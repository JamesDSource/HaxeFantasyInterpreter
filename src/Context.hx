import Data;

typedef Scope = {
    variables: Map<String, Variable>,
    ?parent: Scope
}

typedef Variable = {
    typeInst: DataTypeInstance,
    value: Data
}

class Context {
    public var root(default, null): Scope;
    public var current(default, null): Scope;

    public function new() {
        root = {variables: []};
        current = root;
    }

    public function addScope(): Scope {
        var newScope: Scope = {
            variables: [],
            parent: current
        }

        return current = newScope;
    }

    public function pop(): Scope {
        if(current.parent != null)
            current = current.parent;

        return current;
    }

    public function getVariable(varName: String): Variable {
        var variable: Variable = null;
        var scope: Scope = null;
        do {
            scope = scope == null ? current : scope.parent;
            if(scope.variables.exists(varName))
                variable = scope.variables[varName];
        }
        while(variable == null && scope.parent != null);
        return variable;
    }

    public function setVariable(variable: Variable, value: Data): Bool {
        if(!variableCanHave(variable, value))
            return false;

        variable.value = value;
        return true;
    }

    public function createVariable(varName: String, type: DataTypeInstance, ?init: Data) {
        var variable: Variable = {
            typeInst: type,
            value: Nothing
        };

        if(init != null && !setVariable(variable, init))
            throw 'Could not initialize variable $varName with $init';
            
        
        current.variables[varName] = variable;
    }

    public function variableCanHave(variable: Variable, value: Data): Bool {
        if(variable.typeInst.type == DataTypes.TYPES.DYNAMIC)
            return true;

        return switch (value) {
            case Nothing:
                true;
            case Real(float):
                return variable.typeInst.type == DataTypes.TYPES.REAL;
            case Str(string):
                return variable.typeInst.type == DataTypes.TYPES.STRING;
            case Boolean(bool):
                return variable.typeInst.type == DataTypes.TYPES.BOOL;
            case ArrayList(type, list):
                if(variable.typeInst.type == DataTypes.TYPES.ARRAY_LIST)
                    return variable.typeInst.getDependency().equals(type);

                return false;
            default:
                false;
        }
    }
}
class Main {
    private static function main() {
        var tokens = Tokenizer.getTokens(sys.io.File.getContent("res/code.txt"));
        var tokenString: String = "\n----------------";
        for(token in tokens) 
            tokenString += "\n" + Tokenizer.toString(token.type);
        tokenString += "\n----------------";

        trace(tokenString);

        var parser = new Parser(tokens);
        
        var tree = parser.parse();
        trace(tree.toString());
        
        var context = new Context();
        var r = tree.getResult(context);
        switch(r) {
            case ArrayList(type, list):
                var str = "\n----------------";
                for(item in list)
                    str += '\n${dataText(item)}';
                str += "\n----------------";
                trace(str);
            default:
        }
    }

    public static inline function dataText(data: Data): String {
        return switch(data) {
            case DType(dataType):
                dataType.type.identifier;
            case Nothing:
                "null";
            case Real(float):
                Std.string(float);
            case Str(string):
                '\"$string\"';
            case Boolean(bool):
                Std.string(bool);
            case ArrayList(type, list):
                var lString: String = "[";
                for(i in 0...list.length) {
                    lString += dataText(list[i]);
                    if(i < list.length - 1)
                        lString += ", ";
                }
                lString += "]";
                return 'List<${type.type.identifier}> $lString';
        }
    }
}
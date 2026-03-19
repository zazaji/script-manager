# ScriptManager/Resources/Templates/template.sh
#!/bin/bash
# @Name: New Bash Script
# @Desc: A sample script to demonstrate auto UI generation.
# @Author: You
# @Version: 1.0.0
# @Param: name | string | true | World | Who to greet
# @Param: verbose | bool | false | false | Enable verbose output

NAME="$1"
VERBOSE="$2"

if [ "$VERBOSE" == "--verbose" ]; then
    echo "Verbose mode enabled."
fi

echo "Hello, $NAME!"